/* Chat Message List Widget

   Displays the scrolling list of chat messages inside a rounded
   dark container, with distinct loading, error, empty, and data
   states.

   It handles:
   - subscribing to [messagesStream] and rendering each message as
     a MessageBubble
   - auto-scrolling to the bottom when a new message arrives and the
     user is already near the bottom
   - auto-scrolling when the current user sends their OWN message,
     regardless of scroll position
   - auto-scrolling when the keyboard opens so the input field
     remains visible above the keyboard
   - showing a floating "Nieuwe berichten" chip when new messages
     arrive while the user has scrolled up
   - distinguishing network/Firestore errors from empty state so
     the user sees a helpful wifi-off icon and hint instead of a
     misleading "no messages" message during outages

   All state mutations (counter update, new-messages flag, auto-scroll)
   are deferred to addPostFrameCallback so setState is never called
   during build.
*/

import 'package:flutter/material.dart';
import '../../models/message.dart';
import '../../theme/app_theme.dart';
import 'message_bubble.dart';

class ChatMessageList extends StatefulWidget {
  final Stream<List<Message>> messagesStream;

  const ChatMessageList({super.key, required this.messagesStream});

  @override
  State<ChatMessageList> createState() => _ChatMessageListState();
}

class _ChatMessageListState extends State<ChatMessageList>
    with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();

  int _lastMessageCount = 0;
  String? _lastMessageSignature;
  bool _isNearBottom = true;
  bool _hasNewMessages = false;
  double _lastBottomInset = 0;

  static const double _nearBottomThreshold = 150.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  // Detect keyboard open/close via viewInsets changes.
  //
  // When the keyboard opens we ALWAYS scroll to the bottom so the most
  // recent messages remain visible above the keyboard. This used to only
  // fire when the user was already near the bottom, but that caused the
  // confusing behaviour where tapping the input field after scrolling
  // up would leave old messages in view while the user typed.
  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    final view = View.of(context);
    final bottomInset = view.viewInsets.bottom;

    // Keyboard opened (bottom inset increased)
    if (bottomInset > _lastBottomInset + 10) {
      // Wait for the keyboard animation to finish before scrolling,
      // otherwise the maxScrollExtent is out of date.
      Future.delayed(const Duration(milliseconds: 280), () {
        if (mounted) _scrollToBottom();
      });
    }
    _lastBottomInset = bottomInset;
  }

  // ── Scroll tracking ───────────────────────────────────────────────────────

  void _onScroll() {
    if (!_scrollController.hasClients ||
        !_scrollController.position.hasContentDimensions) {
      return;
    }

    final nearBottom =
        _scrollController.position.maxScrollExtent -
            _scrollController.position.pixels <=
        _nearBottomThreshold;

    if (nearBottom != _isNearBottom) {
      setState(() {
        _isNearBottom = nearBottom;
        if (nearBottom) _hasNewMessages = false;
      });
    }
  }

  Future<void> _scrollToBottom({int retries = 3}) async {
    if (!mounted) return;
    if (_hasNewMessages) {
      setState(() => _hasNewMessages = false);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      if (!_scrollController.hasClients ||
          !_scrollController.position.hasContentDimensions) {
        // Retry after layout completes
        if (retries > 0) {
          await Future.delayed(const Duration(milliseconds: 100));
          _scrollToBottom(retries: retries - 1);
        }
        return;
      }

      try {
        await _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } catch (_) {
        // Handle animation in progress
        if (retries > 0) {
          await Future.delayed(const Duration(milliseconds: 100));
          _scrollToBottom(retries: retries - 1);
        }
      }
    });
  }

  /// All state mutations (counter update + new-messages flag) happen
  /// after the frame completes, never during build.
  ///
  /// If the newest message is from the current user, we always scroll
  /// down regardless of where the user was looking — they just sent
  /// something and expect to see it appear.
  void _handleMessageCountChange(List<Message> messages) {
    final newCount = messages.length;
    if (newCount == _lastMessageCount) return;

    // Detect whether this update was caused by the current user sending
    // a message. If so we always scroll, even if they had scrolled up.
    final newest = messages.isNotEmpty ? messages.last : null;
    final newestSignature = newest == null
        ? null
        : '${newest.username}|${newest.text}|${newest.time}';
    final hadPreviousMessages = _lastMessageCount > 0;
    final isNewMessage = newestSignature != _lastMessageSignature;
    final newestIsOwn =
        hadPreviousMessages &&
        isNewMessage &&
        newest != null &&
        newest.isCurrentUser;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _lastMessageCount = newCount;
      _lastMessageSignature = newestSignature;

      if (_isNearBottom || newestIsOwn) {
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
          horizontal: AppDimensions.paddingXLarge,
        ),
        decoration: AppDecorations.chatList(),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppDimensions.radiusXLarge),
          child: Stack(
            children: [
              _buildStream(),
              if (_hasNewMessages) _buildNewMessagesChip(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Stream builder ────────────────────────────────────────────────────────
  //
  // While the first snapshot is loading we show a small loader. Once we
  // have received at least one snapshot we keep the data pinned to the
  // screen even during re-subscribes so the UI never flashes back to a
  // full-screen spinner — that prevented the input field below from
  // feeling responsive ("je kan pas typen als alle berichten geladen zijn").

  List<Message>? _lastMessages;

  Widget _buildStream() {
    return StreamBuilder<List<Message>>(
      stream: widget.messagesStream,
      builder: (context, snapshot) {
        // First load — nothing cached yet.
        if (snapshot.connectionState == ConnectionState.waiting &&
            _lastMessages == null) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError && _lastMessages == null) {
          return _buildErrorState(snapshot.error);
        }

        final messages = snapshot.data ?? _lastMessages ?? const <Message>[];

        // Cache the most recent non-null snapshot so we can keep showing
        // messages if the stream briefly re-enters a waiting state.
        if (snapshot.hasData) {
          _lastMessages = messages;
        }

        if (messages.isEmpty) {
          return _buildEmptyState();
        }

        _handleMessageCountChange(messages);

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(AppDimensions.paddingMedium),
          itemCount: messages.length,
          itemBuilder: (context, index) =>
              MessageBubble(message: messages[index]),
        );
      },
    );
  }

  // ── Error state ───────────────────────────────────────────────────────────
  //
  // Network/Firestore errors are distinguished from other errors so the
  // user sees a helpful message instead of a raw exception string.

  Widget _buildErrorState(Object? error) {
    final err = error.toString().toLowerCase();
    final isNetwork =
        err.contains('network') ||
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
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return const Center(
      child: Text(
        'Nog geen berichten.\nWees de eerste!',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
      ),
    );
  }

  // ── "New messages" chip ───────────────────────────────────────────────────

  Widget _buildNewMessagesChip() {
    return Positioned(
      bottom: AppDimensions.paddingMedium,
      left: 0,
      right: 0,
      child: Center(
        child: GestureDetector(
          onTap: _scrollToBottom,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
            ),
            child: const Text(
              'Nieuwe berichten ↓',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}