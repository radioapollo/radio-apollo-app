/* Chat Screen

   Main chat screen where users talk to the studio in real time.

   Desktop behaviour
   ─────────────────
   On desktop the username/EULA prompt is skipped entirely. Staff
   members use the admin login (long-press the logo) instead of
   claiming a regular username. The chat input is already shown
   when isAdmin is true, so no username is needed on desktop.

   This avoids calling claimUsername → AppCheckHttp → getToken()
   on a platform that has no App Check provider.
*/

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
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
import '../widgets/chat/admin_login_dialog.dart';
import '../theme/app_theme.dart';
import '../models/message.dart';
import 'admin_reports_screen.dart';

/// True when running on a desktop OS — no App Check provider available.
bool get _isDesktop =>
    !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

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
    // On desktop: try silent auto-login first (uses saved password from
    // a previous session). Only show the login dialog if that fails.
    if (_isDesktop) {
      if (!_authService.isAdmin) {
        final autoOk = await _authService.tryAutoLogin();
        if (autoOk) {
          if (mounted) setState(() {});
          return;
        }
        // No saved password or it expired — show the dialog once.
        if (mounted) {
          await AdminLoginDialog.show(
            context,
            authService: _authService,
            onSuccess: _onAdminLogin,
          );
        }
      }
      return;
    }

    await UserService.instance.init();
    final needsUsername = !UserService.instance.hasUsername;
    final needsEula = !EulaService.instance.hasAccepted;
    if ((needsUsername || needsEula) && mounted) {
      await UsernameDialog.show(context);
      if (mounted) setState(() {});
    }
  }

  Future<void> _promptUsername() async {
    // No username flow on desktop.
    if (_isDesktop) return;

    final name = await UsernameDialog.show(context);
    if (name != null && mounted) {
      setState(() {});
    }
  }

  // ── Reply handlers ────────────────────────────────────────────────────────

  void _onReplyTo(Message message) {
    if (!UserService.instance.hasUsername && !_authService.isAdmin) {
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

    if (!_authService.isAdmin && _cooldownRemaining > 0) {
      _flashCooldownHint();
      return;
    }

    if (_controller.text.trim().isEmpty) return;

    if (!UserService.instance.hasUsername && !_authService.isAdmin) {
      await _promptUsername();
      return;
    }

    final text = _controller.text;
    final replyingTo = _replyingTo;

    setState(() {
      _sending = true;
      _replyingTo = null;
    });
    _controller.clear();
    _textFieldFocus.requestFocus();

    try {
      await _chatService.sendMessage(text, replyingTo: replyingTo);
      if (!_authService.isAdmin) _startCooldown();
    } catch (e) {
      if (mounted) {
        setState(() => _replyingTo = replyingTo);
        _controller.text = text;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _startCooldown() {
    setState(() => _cooldownRemaining = ChatService.cooldownSeconds);
    _cooldownTicker?.cancel();
    _cooldownTicker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        _cooldownRemaining--;
        if (_cooldownRemaining <= 0) t.cancel();
      });
    });
  }

  void _flashCooldownHint() {
    setState(() => _showCooldownHint = true);
    _hintDismissTimer?.cancel();
    _hintDismissTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showCooldownHint = false);
    });
  }

  // ── Admin ─────────────────────────────────────────────────────────────────

  Future<void> _onAdminLogin() async {
    if (mounted) setState(() {});
  }

  Future<void> _onLogout() async {
    _authService.logout();
    if (mounted) setState(() {});
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

              // On desktop: show the input immediately (admin login gives
              // access). On mobile: require a username or admin session.
              if (hasUsername || isAdmin || _isDesktop)
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