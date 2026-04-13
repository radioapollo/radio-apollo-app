/* Chat Screen

   Main chat screen where users talk to the studio in real time.

   Features:
   - Username prompt on first visit, persisted across restarts
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
import '../widgets/chat/message_bubble.dart';
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
  final TextEditingController _controller      = TextEditingController();
  final ScrollController      _scrollController = ScrollController();

  late final Stream<List<Message>> _messagesStream;

  int  _charsLeft        = ChatService.maxMessageLength;
  int  _lastMessageCount = 0;
  bool _usernameChecked  = false;

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
    _scrollController.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _onTextChanged() {
    setState(() {
      _charsLeft = ChatService.maxMessageLength - _controller.text.length;
    });
  }

  Future<void> _ensureUsername() async {
    await UserService.instance.init();
    if (!UserService.instance.hasUsername && mounted) {
      await UsernameDialog.show(context);
      setState(() {});
    }
  }

  Future<void> _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;
    final text = _controller.text;
    _controller.clear();
    await _chatService.sendMessage(text);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollController.hasClients &&
          _scrollController.position.hasContentDimensions) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
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
                authService: _authService,
                onLogout: _onLogout,
              ),
              const SizedBox(height: AppDimensions.spaceMedium),
              _buildChatList(),
              ChatInputField(
                controller: _controller,
                charsLeft:  _charsLeft,
                onSend:     _sendMessage,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Message list ──────────────────────────────────────────────────────────

  Widget _buildChatList() {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingXLarge),
        padding: const EdgeInsets.all(AppDimensions.paddingSmall),
        decoration: AppDecorations.chatList(),
        child: StreamBuilder(
          stream: _messagesStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.loadingIndicator),
              );
            }
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Fout bij laden:\n${snapshot.error}',
                  style: const TextStyle(
                      color: AppColors.textOnDarkMuted, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              );
            }

            final messages = snapshot.data ?? [];
            if (messages.isEmpty) {
              return const Center(
                child: Text(
                  'Nog geen berichten.\nWees de eerste!',
                  style: TextStyle(color: AppColors.loadingIndicator, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              );
            }

            if (messages.length > _lastMessageCount) {
              _lastMessageCount = messages.length;
              WidgetsBinding.instance
                  .addPostFrameCallback((_) => _scrollToBottom());
            }

            return ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.only(
                  bottom: AppDimensions.spaceMedium),
              itemCount: messages.length,
              itemBuilder: (_, index) =>
                  MessageBubble(message: messages[index]),
            );
          },
        ),
      ),
    );
  }
}