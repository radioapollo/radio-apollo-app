/* Chat Screen

   Main chat screen where users talk to the studio in real time.

   This screen is an orchestrator — it manages the username flow,
   admin/studio state, text input, and reply state, then delegates all
   rendering to dedicated child widgets:

   - ChatHeader        → logo + long-press login
   - ChatTitle         → title, username badge, mode badge, logout
   - ChatMessageList   → StreamBuilder with loading/error/empty states
   - ChatInputField    → text field + send button + reply banner
   - UsernamePrompt    → tappable bar shown when no username is set

   Privileged roles
   ────────────────
   Admin and studio are both "privileged" sessions that authenticate
   with a password and post via a session token. Neither needs a
   claimed username, and neither is subject to the user send cooldown.
   The few places that used to check `isAdmin` for "can post without a
   username / skip cooldown" now check `isPrivileged` so studio behaves
   the same way. Moderation entry points (reports inbox) remain
   admin-only.

   Features:
   - Optional username prompt on first visit (can be skipped)
   - Users without a username can read chat but not send messages
   - "Kies een naam" button in the title bar to set a username later
   - Messages streamed live from Firestore (last 48 hours only)
   - 160 character limit with a countdown near the limit
   - Own messages on the right (blue), others on the left
   - Admin messages orange ("Radio Apollo"), studio messages green ("Studio")
   - Per-message action row (like / reply / flag) under each bubble
   - Reply state managed at this level
   - Long-press the logo to open the login
   - Long-press a message: admin only, opens moderation actions
   - Keyboard stays open between messages so the user can keep typing
*/

import 'dart:async';
import 'package:flutter/material.dart';
import '../services/chat/chat_service.dart';
import '../services/chat/auth_service.dart';
import '../services/chat/eula_service.dart';
import '../services/chat/user_service.dart';
import '../widgets/chat/chat_header.dart';
import '../widgets/chat/chat_title.dart';
import '../widgets/chat/chat_input_field.dart';
import '../widgets/chat/chat_message_list.dart';
import '../widgets/chat/username_prompt.dart';
import '../widgets/chat/username_dialog.dart';
import '../theme/app_theme.dart';
import '../models/message.dart';
import 'admin_reports_screen.dart';

class ChatScreen extends StatefulWidget {
  final ChatService chatService;
  final AuthService authService;

  final bool isActive;

  const ChatScreen({
    super.key,
    required this.chatService,
    required this.authService,
    this.isActive = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _textFieldFocus = FocusNode();

  late Stream<List<Message>> _messagesStream;

  int _charsLeft = ChatService.maxMessageLength;
  bool _usernameChecked = false;
  bool _sending = false;
  int _cooldownRemaining = 0;
  bool _showCooldownHint = false;
  Timer? _cooldownTicker;
  Timer? _hintDismissTimer;

  Message? _replyingTo;

  ChatService get _chatService => widget.chatService;
  AuthService get _authService => widget.authService;

  @override
  bool get wantKeepAlive => true;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _messagesStream = _chatService.messagesStream;
    _controller.addListener(_onTextChanged);
    if (widget.isActive) {
      _usernameChecked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _ensureUsername());
    }
  }

  @override
  void didUpdateWidget(ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive && !_usernameChecked) {
      _usernameChecked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _ensureUsername());
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _textFieldFocus.dispose();
    _cooldownTicker?.cancel();
    _hintDismissTimer?.cancel();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _onTextChanged() {
    if (!mounted) return;
    setState(() {
      _charsLeft = ChatService.maxMessageLength - _controller.text.length;
    });
  }

  Future<void> _ensureUsername() async {
    // Privileged sessions (admin/studio) don't need a claimed username.
    if (_authService.isPrivileged) return;
    await UserService.instance.init();
    final needsUsername = !UserService.instance.hasUsername;
    final needsEula = !EulaService.instance.hasAccepted;
    if ((needsUsername || needsEula) && mounted) {
      await UsernameDialog.show(context);
      if (mounted) setState(() {});
    }
  }

  Future<void> _promptUsername() async {
    final name = await UsernameDialog.show(context);
    if (name != null && mounted) {
      setState(() {});
    }
  }

  // ── Reply handlers ────────────────────────────────────────────────────────

  void _onReplyTo(Message message) {
    if (!UserService.instance.hasUsername && !_authService.isPrivileged) {
      _promptUsername();
      return;
    }
    setState(() => _replyingTo = message);
    _textFieldFocus.requestFocus();
  }

  void _onCancelReply() {
    setState(() => _replyingTo = null);
  }

  // ── Send ──────────────────────────────────────────────────────────────────

  Future<void> _sendMessage() async {
    if (_sending) return;

    // Cooldown only applies to regular users, not privileged sessions.
    if (!_authService.isPrivileged && _cooldownRemaining > 0) {
      _flashCooldownHint();
      return;
    }

    if (_controller.text.trim().isEmpty) return;

    if (!UserService.instance.hasUsername && !_authService.isPrivileged) {
      await _promptUsername();
      return;
    }

    final text = _controller.text;
    final replyTarget = _replyingTo;

    setState(() => _sending = true);
    try {
      final ok = await _chatService.sendMessage(text, replyingTo: replyTarget);
      if (!mounted) return;
      if (ok) {
        _controller.clear();
        setState(() {
          _replyingTo = null;
          _charsLeft = ChatService.maxMessageLength;
        });
        _startCooldownTicker();
      }
    } on CooldownException catch (e) {
      _flashCooldownHint(initial: e.secondsRemaining);
    } on ProfanityException catch (e) {
      _showSnack(e.message);
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // ── Cooldown ──────────────────────────────────────────────────────────────

  void _startCooldownTicker() {
    _cooldownTicker?.cancel();
    setState(() => _cooldownRemaining = ChatService.cooldownSeconds);

    _cooldownTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      final remaining = _chatService.cooldownRemaining();
      if (remaining <= 0) {
        timer.cancel();
        setState(() => _cooldownRemaining = 0);
      } else {
        setState(() => _cooldownRemaining = remaining);
      }
    });
  }

  void _flashCooldownHint({int? initial}) {
    if (initial != null) {
      setState(() => _cooldownRemaining = initial);
      _startCooldownTicker();
    }
    setState(() => _showCooldownHint = true);
    _hintDismissTimer?.cancel();
    _hintDismissTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _showCooldownHint = false);
    });
  }

  // ── Snackbar / login / reports ─────────────────────────────────────────────

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        margin: const EdgeInsets.all(AppDimensions.paddingLarge),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        ),
      ),
    );
  }

  void _onAdminLogin() {
    setState(() {
      _messagesStream = _chatService.messagesStream;
    });
  }

  void _onLogout() {
    _authService.logout();
    setState(() {
      _messagesStream = _chatService.messagesStream;
    });
  }

  void _openReports() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AdminReportsScreen()));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final hasUsername = UserService.instance.hasUsername;
    final isAdmin = _authService.isAdmin;
    final isStudio = _authService.isStudio;
    final isPrivileged = _authService.isPrivileged;

    return SizedBox.expand(
      child: Container(
        decoration: BoxDecoration(image: AppDecorations.backgroundWatermark),
        child: SafeArea(
          child: Column(
            children: [
              ChatHeader(
                authService: _authService,
                onAdminLogin: _onAdminLogin,
              ),
              const SizedBox(height: AppDimensions.spaceMedium),
              ChatTitle(
                isAdmin: isAdmin,
                isStudio: isStudio,
                username: UserService.instance.username,
                hasUsername: hasUsername,
                onLogout: _onLogout,
                onPickUsername: _promptUsername,
                onOpenReports: _openReports,
              ),
              const SizedBox(height: AppDimensions.spaceMedium),
              ChatMessageList(
                messagesStream: _messagesStream,
                onReply: _onReplyTo,
              ),

              // ── Input area: real input or "pick a name" prompt ──────────
              if (hasUsername || isPrivileged)
                ChatInputField(
                  controller: _controller,
                  focusNode: _textFieldFocus,
                  maxLength: ChatService.maxMessageLength,
                  charsLeft: _charsLeft,
                  onSend: _sendMessage,
                  isSending: _sending,
                  cooldownRemaining: _cooldownRemaining,
                  showCooldownHint: _showCooldownHint,
                  replyingTo: _replyingTo,
                  onCancelReply: _onCancelReply,
                )
              else
                UsernamePrompt(onTap: _promptUsername),
            ],
          ),
        ),
      ),
    );
  }
}