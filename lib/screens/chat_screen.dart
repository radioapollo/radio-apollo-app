/* Chat Screen

   This screen lets users chat with the studio in real time.

   Features:
   - Username prompt shown only the first time the user opens this screen
   - Messages streamed live from Firestore (last 24 hours only)
   - 160 character limit with a countdown shown below 30 chars remaining
   - Own messages appear on the right (blue), others on the left
   - Admin messages appear in orange with a radio icon
   - Long-press the logo to open the admin login
*/

import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../widgets/message_bubble.dart';
import '../widgets/username_dialog.dart';
import '../theme/app_theme.dart';
import '../constants/constants.dart';
import '../models/message.dart';

class ChatScreen extends StatefulWidget {
  final ChatService chatService;
  final AuthService authService;
  /// Set to true when this tab is the active/visible one.
  /// Used to defer the username prompt until the user actually opens the chat.
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

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller       = TextEditingController();
  final ScrollController       _scrollController = ScrollController();

  int _charsLeft = ChatService.maxMessageLength;

  late final Stream<List<Message>> _messagesStream;

  int _lastMessageCount = 0;

  bool _usernameChecked = false;

  ChatService get _chatService => widget.chatService;
  AuthService get _authService => widget.authService;

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
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(AppAssets.watermark),
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: AppDimensions.spaceMedium),
              _buildChatTitle(),
              const SizedBox(height: AppDimensions.spaceMedium),
              _buildChatList(),
              _buildInputField(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.paddingXLarge,
        AppDimensions.paddingXLarge,
        AppDimensions.paddingXLarge,
        0,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: GestureDetector(
          onLongPress: _authService.isAdmin ? null : _showAdminLogin,
          child: Image.asset(
            AppAssets.logo,
            height: AppDimensions.logoHeight,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  Widget _buildChatTitle() {
    final username = UserService.instance.username;

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingXLarge),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Chat met de Studio',
                    style: AppTextStyles.chatTitle),
                if (_authService.isAdmin)
                  const Padding(
                    padding: EdgeInsets.only(top: AppDimensions.spaceSmall),
                    child: Text('ADMIN MODE',
                        style: AppTextStyles.adminBadge),
                  )
                else if (username != null)
                  Padding(
                    padding: const EdgeInsets.only(
                        top: AppDimensions.spaceXSmall),
                    child: Text(
                      'Ingelogd als: $username',
                      style: const TextStyle(
                          color: Colors.black54, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          if (_authService.isAdmin)
            TextButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout,
                  size: 18, color: Colors.black54),
              label: const Text('Uitloggen',
                  style: TextStyle(
                      color: Colors.black54, fontSize: 13)),
            ),
        ],
      ),
    );
  }

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
                child: CircularProgressIndicator(color: Colors.white38),
              );
            }
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Fout bij laden:\n${snapshot.error}',
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              );
            }

            final messages = snapshot.data ?? [];
            if (messages.isEmpty) {
              return const Center(
                child: Text(
                  'Nog geen berichten.\nWees de eerste!',
                  style: TextStyle(color: Colors.white38, fontSize: 14),
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
              itemBuilder: (context, index) =>
                  MessageBubble(message: messages[index]),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInputField() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingMedium,
        vertical:   AppDimensions.paddingSmall,
      ),
      margin: const EdgeInsets.fromLTRB(
        AppDimensions.paddingXLarge,
        AppDimensions.spaceMedium,
        AppDimensions.paddingXLarge,
        AppDimensions.paddingXLarge,
      ),
      decoration: AppDecorations.chatInputFull(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller:  _controller,
                  style:       AppTextStyles.inputText,
                  maxLength:   ChatService.maxMessageLength,
                  buildCounter: (_, {required currentLength,
                      required isFocused, maxLength}) => null,
                  decoration: const InputDecoration(
                    hintText:  'Typ een bericht...',
                    hintStyle: AppTextStyles.inputHint,
                    border:    InputBorder.none,
                    isDense:   true,
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
                if (_charsLeft <= 30)
                  Text(
                    '$_charsLeft',
                    style: TextStyle(
                      color: _charsLeft <= 10
                          ? Colors.redAccent
                          : Colors.white38,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppDimensions.spaceSmall),
          GestureDetector(
            onTap: _sendMessage,
            child: const Icon(
              Icons.send,
              color: Colors.white,
              size:  AppDimensions.iconLarge,
            ),
          ),
        ],
      ),
    );
  }

  void _logout() {
    _authService.logout();
    setState(() {});
  }

  void _showAdminLogin() {
    final passwordController = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Admin Login'),
        content: TextField(
          controller:  passwordController,
          obscureText: true,
          decoration:  const InputDecoration(hintText: 'Wachtwoord'),
          onSubmitted: (_) async {
            try {
              await _authService.login(passwordController.text);
              if (mounted) {
                setState(() {});
                Navigator.pop(context);
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ongeldig wachtwoord')),
                );
              }
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuleren'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await _authService.login(passwordController.text);
                if (mounted) {
                  setState(() {});
                  Navigator.pop(context);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ongeldig wachtwoord')),
                  );
                }
              }
            },
            child: const Text('Login'),
          ),
        ],
      ),
    );
  }
}