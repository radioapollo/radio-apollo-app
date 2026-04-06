/* Chat Screen

   This screen lets users chat with the studio in real time.

   Features:
   - Username prompt on first visit (stored locally, shown once)
   - Messages streamed live from Firestore
   - Only messages from the last 24 hours are shown
   - Messages are limited to 160 characters
   - Own messages appear on the right (blue), others on the left
   - Admin messages appear in orange with a radio icon
*/

import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../services/user_service.dart';
import '../widgets/username_dialog.dart';
import '../theme/app_theme.dart';
import '../constants/constants.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _chatService = ChatService();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Ask for a username the first time the user opens this screen.
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureUsername());
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _ensureUsername() async {
    if (!UserService.instance.hasUsername && mounted) {
      await UsernameDialog.show(context);
      setState(() {}); // refresh so the username shows in the header
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
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

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
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
              _buildMessageList(),
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
        child: Image.asset(
          AppAssets.logo,
          height: AppDimensions.logoHeight,
          fit: BoxFit.contain,
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
                if (username != null)
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
          // Allow user to change their username
          if (username != null)
            TextButton.icon(
              onPressed: () async {
                await UserService.instance.clearUsername();
                setState(() {});
                if (mounted) {
                  await UsernameDialog.show(context);
                  setState(() {});
                }
              },
              icon: const Icon(Icons.edit, size: 16, color: Colors.black45),
              label: const Text('Naam',
                  style: TextStyle(color: Colors.black45, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingXLarge),
        padding: const EdgeInsets.all(AppDimensions.paddingSmall),
        decoration: AppDecorations.chatList(),
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: _chatService.messagesStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                    color: AppColors.steelLight),
              );
            }
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Fout bij laden: ${snapshot.error}',
                  style: const TextStyle(color: Colors.white54),
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

            // Auto-scroll when new messages arrive
            WidgetsBinding.instance.addPostFrameCallback(
                (_) => _scrollToBottom());

            return ListView.builder(
              controller: _scrollController,
              padding:
                  const EdgeInsets.only(bottom: AppDimensions.spaceMedium),
              itemCount: messages.length,
              itemBuilder: (context, index) =>
                  _buildBubble(messages[index]),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBubble(Map<String, dynamic> msg) {
    final myUsername = UserService.instance.username;
    final msgUsername = msg['username'] as String;
    final text = msg['text'] as String;
    final time = msg['timestamp'] as DateTime;
    final isMe = msgUsername == myUsername;

    return Container(
      margin: EdgeInsets.only(
        top: AppDimensions.spaceSmall,
        bottom: AppDimensions.spaceSmall,
        left: isMe ? 60 : 0,
        right: isMe ? 0 : 60,
      ),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Username label (only for other people's messages)
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(
                  left: AppDimensions.spaceSmall,
                  bottom: AppDimensions.spaceXSmall),
              child: Text(
                msgUsername,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Container(
            padding:
                const EdgeInsets.all(AppDimensions.paddingSmall),
            decoration: BoxDecoration(
              color: isMe ? AppColors.primaryLight : AppColors.steelMedium,
              borderRadius:
                  BorderRadius.circular(AppDimensions.radiusMedium),
            ),
            child: Text(
              text,
              style: const TextStyle(
                  color: Colors.white, fontSize: 15),
            ),
          ),
          const SizedBox(height: AppDimensions.spaceXSmall),
          Text(_formatTime(time),
              style: const TextStyle(
                  color: Colors.white38, fontSize: 11)),
        ],
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
              maxLength: ChatService.maxMessageLength,
              // Hide the counter — we'll show remaining chars ourselves
              buildCounter: (_, {required currentLength, required isFocused, maxLength}) {
                final remaining = (maxLength ?? 160) - currentLength;
                return remaining <= 30
                    ? Text(
                        '$remaining',
                        style: TextStyle(
                          color: remaining <= 10
                              ? Colors.redAccent
                              : Colors.white38,
                          fontSize: 11,
                        ),
                      )
                    : null;
              },
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
                color: Colors.white,
                size: AppDimensions.iconLarge),
          ),
        ],
      ),
    );
  }
}