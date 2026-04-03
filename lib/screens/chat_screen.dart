import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../services/auth_service.dart';
import '../widgets/message_bubble.dart';
import '../theme/app_theme.dart';
import '../constants/constants.dart';

class ChatScreen extends StatefulWidget {
  final ChatService chatService;
  final AuthService authService;

  const ChatScreen({
    super.key,
    required this.chatService,
    required this.authService,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller       = TextEditingController();
  final ScrollController       _scrollController = ScrollController();

  ChatService get _chatService => widget.chatService;
  AuthService get _authService => widget.authService;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    if (_controller.text.trim().isEmpty) return;
    _chatService.sendMessage(_controller.text);
    _controller.clear();
    setState(() {});
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
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
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingXLarge),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Chat met de Studio', style: AppTextStyles.chatTitle),
                if (_authService.isAdmin)
                  const Padding(
                    padding: EdgeInsets.only(top: AppDimensions.spaceSmall),
                    child: Text('ADMIN MODE', style: AppTextStyles.adminBadge),
                  ),
              ],
            ),
          ),
          if (_authService.isAdmin)
            TextButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout, size: 18, color: Colors.black54),
              label: const Text(
                'Uitloggen',
                style: TextStyle(color: Colors.black54, fontSize: 13),
              ),
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
        child: ListView.builder(
          controller: _scrollController,
          itemCount: _chatService.messages.length,
          padding:
              const EdgeInsets.only(bottom: AppDimensions.spaceMedium),
          itemBuilder: (context, index) {
            return MessageBubble(message: _chatService.messages[index]);
          },
        ),
      ),
    );
  }

  Widget _buildInputField() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingMedium,
        vertical: AppDimensions.paddingSmall,
      ),
      margin: const EdgeInsets.fromLTRB(
        AppDimensions.paddingXLarge,
        AppDimensions.spaceMedium,
        AppDimensions.paddingXLarge,
        AppDimensions.paddingXLarge,
      ),
      decoration: AppDecorations.chatInputFull(),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              style: AppTextStyles.inputText,
              decoration: const InputDecoration(
                hintText: 'Typ een bericht...',
                hintStyle: AppTextStyles.inputHint,
                border: InputBorder.none,
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          GestureDetector(
            onTap: _sendMessage,
            child: const Icon(Icons.send,
                color: Colors.white, size: AppDimensions.iconLarge),
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
          controller: passwordController,
          obscureText: true,
          decoration: const InputDecoration(hintText: 'Wachtwoord'),
          onSubmitted: (_) {
            _authService.login(passwordController.text);
            setState(() {});
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuleren'),
          ),
          TextButton(
            onPressed: () {
              _authService.login(passwordController.text);
              setState(() {});
              Navigator.pop(context);
            },
            child: const Text('Login'),
          ),
        ],
      ),
    );
  }
}