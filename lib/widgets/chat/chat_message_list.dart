/* Chat Message List Widget

   FIXES APPLIED:
   - Network/Firestore errors caught and shown as user-friendly messages
     instead of raw exception strings (Issue: Technical Firestore error shown to user)
   - Empty state and error state have distinct messages so users are not
     misled during network failures (Issue: Misleading messages during network failures)
   - Auto-scroll bookkeeping no longer calls setState during build — all
     mutations deferred to addPostFrameCallback.
*/

import 'package:flutter/material.dart';
import '../../models/message.dart';
import '../../theme/app_theme.dart';
import 'message_bubble.dart';

class ChatMessageList extends StatefulWidget {
  final Stream<List<Message>> messagesStream;

  const ChatMessageList({
    super.key,
    required this.messagesStream,
  });

  @override
  State<ChatMessageList> createState() => _ChatMessageListState();
}

class _ChatMessageListState extends State<ChatMessageList> {
  final ScrollController _scrollController = ScrollController();

  int  _lastMessageCount = 0;
  bool _isNearBottom      = true;
  bool _hasNewMessages    = false;

  static const double _nearBottomThreshold = 150.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients ||
        !_scrollController.position.hasContentDimensions) return;

    final nearBottom = _scrollController.position.maxScrollExtent -
            _scrollController.position.pixels <=
        _nearBottomThreshold;

    if (nearBottom != _isNearBottom) {
      setState(() {
        _isNearBottom = nearBottom;
        if (nearBottom) _hasNewMessages = false;
      });
    }
  }

  Future<void> _scrollToBottom() async {
    if (!mounted) return;
    setState(() => _hasNewMessages = false);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!_scrollController.hasClients ||
          !_scrollController.position.hasContentDimensions) return;

      await _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  /// FIX: all state mutations (counter update + new-messages flag) happen
  /// after the frame completes, never during build.
  void _handleMessageCountChange(int newCount) {
    if (newCount == _lastMessageCount) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _lastMessageCount = newCount;
      if (_isNearBottom) {
        _scrollToBottom();
      } else {
        setState(() => _hasNewMessages = true);
      }
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingXLarge),
        decoration: AppDecorations.chatList(),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppDimensions.radiusXLarge),
          child: Stack(
            children: [
              StreamBuilder<List<Message>>(
                stream: widget.messagesStream,
                builder: (context, snapshot) {
                  // ── Loading ───────────────────────────────────────────────
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // FIX: Distinguish network/Firestore errors from empty state
                  if (snapshot.hasError) {
                    final err = snapshot.error.toString().toLowerCase();
                    final isNetwork = err.contains('network') ||
                        err.contains('unavailable') ||
                        err.contains('deadline') ||
                        err.contains('timeout');

                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppDimensions.paddingLarge),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isNetwork ? Icons.wifi_off : Icons.error_outline,
                              color: AppColors.textSecondary,
                              size: 32,
                            ),
                            const SizedBox(height: AppDimensions.spaceSmall),
                            Text(
                              isNetwork
                                  ? 'Geen internetverbinding.\nControleer je netwerk en probeer opnieuw.'
                                  : 'Berichten konden niet worden geladen.\nProbeer het later opnieuw.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: AppColors.textSecondary, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  // Empty state
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                      child: Text(
                        'Nog geen berichten.\nWees de eerste!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 13),
                      ),
                    );
                  }

                  // ── Message list ──────────────────────────────────────────
                  final messages = snapshot.data!;

                  // FIX: defer the diff handling; no setState during build.
                  _handleMessageCountChange(messages.length);

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(AppDimensions.paddingMedium),
                    itemCount: messages.length,
                    itemBuilder: (context, index) =>
                        MessageBubble(message: messages[index]),
                  );
                },
              ),

              // Floating "new messages" chip
              if (_hasNewMessages)
                Positioned(
                  bottom: AppDimensions.paddingMedium,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: _scrollToBottom,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(
                              AppDimensions.radiusFull),
                        ),
                        child: const Text(
                          'Nieuwe berichten ↓',
                          style: TextStyle(
                              color: AppColors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}