/* Chat Screen

   Main chat screen where users talk to the studio in real time.

   This screen is an orchestrator — it manages the username flow,
   admin state, and text input, then delegates all rendering to
   dedicated child widgets:

   - ChatHeader        → logo + long-press admin login
   - ChatTitle         → title, username badge, logout / pick-name button
   - ChatMessageList   → StreamBuilder with loading/error/empty states
   - ChatInputField    → text field + send button
   - UsernamePrompt    → tappable bar shown when no username is set

   Features:
   - Optional username prompt on first visit (can be skipped)
   - Users without a username can read chat but not send messages
   - "Kies een naam" button in the title bar to set a username later
   - Messages streamed live from Firestore (last 48 hours only)
   - 160 character limit with a countdown near the limit
   - Own messages on the right (blue), others on the left
   - Admin messages in orange with a radio icon
   - Long-press the logo to open the admin login
   - Keyboard stays open between messages so the user can keep typing
*/

import 'dart:async';
import 'package:flutter/material.dart';
import '../services/chat/chat_service.dart';
import '../services/chat/auth_service.dart';
import '../services/chat/user_service.dart';
import '../widgets/chat/chat_header.dart';
import '../widgets/chat/chat_title.dart';
import '../widgets/chat/chat_input_field.dart';
import '../widgets/chat/chat_message_list.dart';
import '../widgets/chat/username_prompt.dart';
import '../widgets/chat/username_dialog.dart';
import '../theme/app_theme.dart';
import '../models/message.dart';

class ChatScreen extends StatefulWidget {
  final ChatService chatService;
  final AuthService authService;

  /// Set to true when this tab is the active/visible one.
  /// Used to defer the username prompt until the user opens the chat.
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

  late final Stream<List<Message>> _messagesStream;

  int _charsLeft = ChatService.maxMessageLength;
  bool _usernameChecked = false;
  bool _sending = false;
  int _cooldownRemaining = 0;
  bool _showCooldownHint = false;
  Timer? _cooldownTicker;
  Timer? _hintDismissTimer;

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

  /// Initialises UserService and shows the username dialog if needed.
  /// The dialog is dismissible — if the user cancels, they can still
  /// read the chat but cannot send messages until they pick a name.
  Future<void> _ensureUsername() async {
    await UserService.instance.init();
    if (!UserService.instance.hasUsername && mounted) {
      await UsernameDialog.show(context);
      if (mounted) setState(() {});
    }
  }

  /// Opens the username dialog on demand (e.g. from the title bar button
  /// or the input-area prompt).
  Future<void> _promptUsername() async {
    final name = await UsernameDialog.show(context);
    if (name != null && mounted) {
      setState(() {});
    }
  }

  // ── Send ──────────────────────────────────────────────────────────────────

  /// Safety guard: should never be reached because the UI hides the input
  /// field when hasUsername is false, but guards against any edge-case
  /// where _sendMessage is somehow called without a username.
  Future<void> _sendMessage() async {
    if (_sending) return;

    // Admins bypass the per-user cooldown entirely, so don't flash or
    // block them. Regular users see the hint if they tap while waiting.
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
    // Remember whether the keyboard/focus was up so we can restore it
    // exactly as it was once the message has flown out. This is the fix
    // for "tussen berichten in moet er opnieuw op tekstvak getikt worden":
    // the send flow briefly rebuilds, and if we only request focus when
    // it's still held we end up losing it to the bottom of the tree.
    final keepFocus = _textFieldFocus.hasFocus;

    _controller.clear();
    setState(() => _sending = true);

    try {
      await _chatService.sendMessage(text);

      // Always restore focus to the input field after a successful send,
      // regardless of what happened during the async gap. This keeps the
      // keyboard open so the user can type the next message immediately.
      if (mounted && keepFocus && !_textFieldFocus.hasFocus) {
        _textFieldFocus.requestFocus();
      }

      // Only regular users have a send cooldown — admins are unlimited.
      if (!_authService.isAdmin) {
        _startCooldown();
      }
    } on CooldownException catch (e) {
      // Rare: the service's clock disagreed with ours. Start the countdown
      // using the service's number instead of showing a red error.
      if (!mounted) return;
      _controller.text = text;
      _startCooldown(seconds: e.secondsRemaining);
      _flashCooldownHint();
    } catch (e) {
      if (!mounted) return;
      // Put the text back so the user doesn't lose what they typed
      _controller.text = text;
      _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // ── Cooldown ──────────────────────────────────────────────────────────────

  /// Starts the visible countdown on the send button. Ticks once per
  /// second until it reaches zero, then cancels itself.
  ///
  /// The previous implementation re-read the remaining seconds from the
  /// service on each tick. That caused two visible issues:
  ///   1. The pill could briefly show the wrong number (0 → 3 → 2 → 1)
  ///      because the service's reference time is set after the network
  ///      request returns, while the UI starts ticking before then.
  ///   2. If the user sent a message through the admin path (which does
  ///      NOT update _lastMessageSent on the service), the countdown
  ///      would immediately snap to 0.
  /// Instead we just decrement a local counter — simple and stable.
  void _startCooldown({int? seconds}) {
    _cooldownTicker?.cancel();

    if (!mounted) return;

    final initial = seconds ?? ChatService.cooldownSeconds;
    setState(() {
      _cooldownRemaining = initial;
    });

    _cooldownTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        _cooldownTicker = null;
        return;
      }

      final next = _cooldownRemaining - 1;

      if (next <= 0) {
        timer.cancel();
        _cooldownTicker = null;
        setState(() => _cooldownRemaining = 0);
      } else {
        setState(() => _cooldownRemaining = next);
      }
    });
  }

  /// Briefly shows an inline "nog Xs" hint inside the input field when the
  /// user taps send during cooldown. Auto-dismisses after 1.5s.
  void _flashCooldownHint() {
    _hintDismissTimer?.cancel();
    setState(() => _showCooldownHint = true);
    _hintDismissTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      setState(() => _showCooldownHint = false);
    });
  }

  // ── Error snackbar (real errors only) ─────────────────────────────────────

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.live,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        margin: const EdgeInsets.all(AppDimensions.paddingLarge),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        ),
      ),
    );
  }

  void _onAdminLogin() => setState(() {});

  void _onLogout() {
    _authService.logout();
    setState(() {});
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin

    final hasUsername = UserService.instance.hasUsername;
    final isAdmin = _authService.isAdmin;

    return SizedBox.expand(
      child: Container(
        decoration: const BoxDecoration(
          image: AppDecorations.backgroundWatermark,
        ),
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
              ),
              const SizedBox(height: AppDimensions.spaceMedium),
              ChatMessageList(messagesStream: _messagesStream),

              // ── Input area: real input or "pick a name" prompt ──────────
              if (hasUsername || isAdmin)
                ChatInputField(
                  controller: _controller,
                  focusNode: _textFieldFocus,
                  maxLength: ChatService.maxMessageLength,
                  charsLeft: _charsLeft,
                  onSend: _sendMessage,
                  isSending: _sending,
                  cooldownRemaining: _cooldownRemaining,
                  showCooldownHint: _showCooldownHint,
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
