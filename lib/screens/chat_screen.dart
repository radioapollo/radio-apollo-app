import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../widgets/message_bubble.dart';
import '../theme/app_theme.dart';

class ChatScreen extends StatefulWidget {
  final ChatService chatService;

  const ChatScreen({super.key, required this.chatService});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller     = TextEditingController();
  final ScrollController       _scrollController = ScrollController();

  ChatService get _chatService => widget.chatService;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    if (_controller.text.trim().isEmpty) return;
    setState(() {
      _chatService.sendMessage(_controller.text);
      _controller.clear();
    });
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
        decoration: const BoxDecoration(
          image: AppDecorations.backgroundWatermark,
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
          onLongPress: _showAdminLogin,
          child: Image.asset(
            '../lib/assets/images/Logo/transparant.png',
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Chat met de Studio', style: AppTextStyles.chatTitle),
          if (_chatService.currentRole == 'admin')
            const Padding(
              padding:
                  EdgeInsets.only(top: AppDimensions.spaceSmall),
              child: Text('ADMIN MODE', style: AppTextStyles.adminBadge),
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

  void _showAdminLogin() {
    final passwordController = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Admin Login'),
        content: TextField(
          controller: passwordController,
          obscureText: true,
          decoration: const InputDecoration(hintText: 'Enter password'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _chatService.loginAsAdmin(passwordController.text);
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