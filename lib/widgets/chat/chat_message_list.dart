/* Chat Message List Widget

   Displays the live-updating list of chat messages inside a styled
   container. Handles loading, error, and empty states internally.

   Scroll behaviour:
   - When the user is near the bottom (within _nearBottomThreshold),
     new messages auto-scroll the list down.
   - When the user has scrolled up to read older messages, a floating
     "Nieuwe berichten ↓" chip appears instead. Tapping it scrolls
     to the bottom and dismisses the chip.
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

  /// How close (in pixels) the user must be to the bottom for
  /// auto-scroll to kick in. A comfortable threshold so that
  /// being "almost at the bottom" still counts.
  static const double _nearBottomThreshold = 150.0;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

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

  // ── Scroll helpers ────────────────────────────────────────────────────────

  void _onScroll() {
    if (!_scrollController.hasClients ||
        !_scrollController.position.hasContentDimensions) return;

    final nearBottom = _scrollController.position.maxScrollExtent -
            _scrollController.position.pixels <=
        _nearBottomThreshold;

    if (nearBottom != _isNearBottom) {
      setState(() {
        _isNearBottom = nearBottom;
        // Dismiss the chip as soon as the user scrolls back down
        if (nearBottom) _hasNewMessages = false;
      });
    }
  }

  Future<void> _scrollToBottom() async {
    setState(() => _hasNewMessages = false);

    // Wait one frame so the ListView has laid out any new messages
    // and maxScrollExtent reflects the true bottom.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!_scrollController.hasClients ||
          !_scrollController.position.hasContentDimensions) return;

      await _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );

      // The chip dismissal and animation can shift layout slightly,
      // so snap to the true bottom once everything has settled.
      if (_scrollController.hasClients &&
          _scrollController.position.hasContentDimensions) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  /// Called after the StreamBuilder detects new messages.
  void _onNewMessages() {
    if (_isNearBottom) {
      // User is at (or near) the bottom → scroll automatically
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _scrollToBottom());
    } else {
      // User is reading older messages → show the chip
      setState(() => _hasNewMessages = true);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingXLarge),
        padding: const EdgeInsets.all(AppDimensions.paddingSmall),
        decoration: AppDecorations.chatList(),
        child: StreamBuilder<List<Message>>(
          stream: widget.messagesStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                    color: AppColors.loadingIndicator),
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
                  style: TextStyle(
                      color: AppColors.loadingIndicator, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              );
            }

            // Detect new messages
            if (messages.length > _lastMessageCount) {
              _lastMessageCount = messages.length;
              WidgetsBinding.instance
                  .addPostFrameCallback((_) => _onNewMessages());
            }

            return Stack(
              children: [
                ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(
                      bottom: AppDimensions.spaceMedium),
                  itemCount: messages.length,
                  itemBuilder: (_, index) =>
                      MessageBubble(message: messages[index]),
                ),

                // ── "New messages" chip ─────────────────────────────────────
                if (_hasNewMessages)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: AppDimensions.paddingSmall,
                    child: Center(
                      child: GestureDetector(
                        onTap: _scrollToBottom,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(
                                AppDimensions.radiusFull),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Nieuwe berichten',
                                style: TextStyle(
                                  color: AppColors.textOnDark,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(
                                Icons.keyboard_arrow_down,
                                color: AppColors.textOnDark,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}