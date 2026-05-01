/* Chat Message List Widget

   Displays the scrolling list of chat messages inside a rounded
   dark container, with distinct loading, error, empty, and data
   states.

   It handles:
   - subscribing to [messagesStream] and rendering each message as
     a MessageBubble
   - jumping straight to the bottom on the very first data load so
     the user always opens onto the newest message
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

   ─── Initial scroll reliability ────────────────────────────────────────────
   The previous implementation only used `addPostFrameCallback` once and
   then animated to maxScrollExtent. That broke for some users on first
   open because chat bubbles have variable heights and the ListView
   reports a still-growing maxScrollExtent across the first few layout
   passes (each bubble only measures its real height once it's about to
   appear). The animation would then "land" at what was the bottom one
   frame ago, leaving newer messages cut off.

   The fix: on the very first data arrival, run a short settle loop —
   multiple jumpTo(maxScrollExtent) calls across consecutive frames,
   without animation. Each pass corrects for any extent growth from the
   previous frame. After that, regular animated scrolling takes over for
   live updates.
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

  /// True until the very first non-empty data snapshot has been
  /// rendered AND we've successfully landed at the bottom. While this
  /// is false we use the aggressive "settle" sequence instead of a
  /// single animated scroll.
  bool _initialScrollDone = false;

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

  /// Animated scroll to the bottom — used for live updates after the
  /// initial load has settled.
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

  /// Used on the very first data load. Instead of a single animated
  /// scroll, we jump (no animation) to maxScrollExtent across several
  /// frames. Each pass corrects for any extent growth caused by
  /// variable-height bubbles laying out late, so the user always
  /// lands at the actual newest message instead of where the bottom
  /// "used to be" one frame ago.
  void _settleAtBottom({int passes = 6}) {
    if (!mounted || passes <= 0) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (!_scrollController.hasClients ||
          !_scrollController.position.hasContentDimensions) {
        // Layout hasn't happened yet — try again next frame.
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted) _settleAtBottom(passes: passes - 1);
        });
        return;
      }

      final target = _scrollController.position.maxScrollExtent;
      try {
        _scrollController.jumpTo(target);
      } catch (_) {
        // Ignore — we'll try again next pass.
      }

      // Schedule one more pass to catch any further extent growth.
      // We stop early if the position is already at the bottom AND
      // the extent stopped growing between passes.
      Future.delayed(const Duration(milliseconds: 32), () {
        if (!mounted) return;
        if (!_scrollController.hasClients) {
          _settleAtBottom(passes: passes - 1);
          return;
        }
        final newMax = _scrollController.position.maxScrollExtent;
        final atBottom =
            (newMax - _scrollController.position.pixels).abs() < 1.0;
        if (atBottom && newMax == target) {
          // Settled. Mark initial done so future updates use the
          // animated path.
          _initialScrollDone = true;
          return;
        }
        _settleAtBottom(passes: passes - 1);
      });
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

    // Capture whether this is the first time we're seeing data so the
    // post-frame callback below knows which scroll strategy to use.
    final isFirstLoad = !_initialScrollDone;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _lastMessageCount = newCount;
      _lastMessageSignature = newestSignature;

      if (isFirstLoad) {
        // First time we're rendering messages — guarantee the user
        // lands at the bottom even if bubble heights are still being
        // measured across the next few frames.
        _settleAtBottom();
        return;
      }

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
