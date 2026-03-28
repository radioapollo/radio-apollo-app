/* Chat Screen

   This screen allows users to interact with the radio station
   through a chat interface.

   Features include:
   - viewing messages from the studio
   - sending messages to the radio station
   - displaying messages in chat bubbles
*/

import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../widgets/message_bubble.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final ChatService _chatService;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _chatService = ChatService();
  }

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
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 10),
          _buildChatList(),
          _buildInputField(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        GestureDetector(
          onLongPress: _showAdminLogin,
          child: const Text(
            "RADIO APOLLO",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            "Chat met de Studio",
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (_chatService.currentRole == "admin")
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text(
            "ADMIN MODE",
            style: TextStyle(
              color: Colors.orangeAccent,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChatList() {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF18375A),
          borderRadius: BorderRadius.circular(20),
        ),
        child: ListView.builder(
          controller: _scrollController,
          itemCount: _chatService.messages.length,
          padding: const EdgeInsets.only(bottom: 10),
          itemBuilder: (context, index) {
            final message = _chatService.messages[index];
            return MessageBubble(message: message);
          },
        ),
      ),
    );
  }

  Widget _buildInputField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      decoration: BoxDecoration(
        color: const Color(0xFF102F52),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: "Typ een bericht...",
                hintStyle: TextStyle(color: Colors.white54),
                border: InputBorder.none,
              ),
            ),
          ),
          GestureDetector(
            onTap: _sendMessage,
            child: const Icon(Icons.send, color: Colors.white, size: 26),
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
        title: const Text("Admin Login"),
        content: TextField(
          controller: passwordController,
          obscureText: true,
          decoration: const InputDecoration(
            hintText: "Enter password",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _chatService.loginAsAdmin(passwordController.text);
              setState(() {}); // refresh UI
              Navigator.pop(context);
            },
            child: const Text("Login"),
          ),
        ],
      ),
    );
  }
}