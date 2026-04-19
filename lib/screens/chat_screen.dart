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
   - Messages streamed live from Firestore (last 24 hours only)
   - 160 character limit with a countdown near the limit
   - Own messages on the right (blue), others on the left
   - Admin messages in orange with a radio icon
   - Long-press the logo to open the admin login
*/

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

  late final Stream<List<Message>> _messagesStream;

  int  _charsLeft       = ChatService.maxMessageLength;
  bool _usernameChecked = false;

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
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _onTextChanged() {
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
      setState(() {});
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

  /// Safety guard: should never be reached because the UI hides the input
  /// field when hasUsername is false, but guards against any edge-case
  /// where _sendMessage is somehow called without a username.
  Future<void> _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;

    if (!UserService.instance.hasUsername && !_authService.isAdmin) {
      await _promptUsername();
      return;
    }

    final text = _controller.text;
    _controller.clear();
    await _chatService.sendMessage(text);
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
    final isAdmin     = _authService.isAdmin;

    return SizedBox.expand(
      child: Container(
        decoration: const BoxDecoration(
          image: AppDecorations.backgroundWatermark,
        ),
        child: SafeArea(
          child: Column(
            children: [
              ChatHeader(
                authService:  _authService,
                onAdminLogin: _onAdminLogin,
              ),
              const SizedBox(height: AppDimensions.spaceMedium),
              ChatTitle(
                isAdmin:        isAdmin,
                username:       UserService.instance.username,
                hasUsername:    hasUsername,
                onLogout:       _onLogout,
                onPickUsername: _promptUsername,
              ),
              const SizedBox(height: AppDimensions.spaceMedium),
              ChatMessageList(messagesStream: _messagesStream),

              // ── Input area: real input or "pick a name" prompt ──────────
              if (hasUsername || isAdmin)
                ChatInputField(
                  controller: _controller,
                  maxLength:  ChatService.maxMessageLength,
                  charsLeft:  _charsLeft,
                  onSend:     _sendMessage,
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