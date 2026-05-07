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
   - forwarding the [onReply] callback to each MessageBubble so the
     parent chat screen can manage the active reply target

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
import '../../services/chat/block_service.dart';
import 'message_bubble.dart';

class ChatMessageList extends StatefulWidget {
  final Stream<List<Message>> messagesStream;
  final ValueChanged<Message>? onReply;

  const ChatMessageList({
    super.key,
    required this.messagesStream,
    this.onReply,
  });

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

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    final view = View.of(context);
    final bottomInset = view.viewInsets.bottom;

    if (bottomInset > _lastBottomInset + 10) {
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
        if (retries > 0) {
          await Future.delayed(const Duration(milliseconds: 100));
          _scrollToBottom(retries: retries - 1);
        }
      }
    });
  }

  void _settleAtBottom({int passes = 6}) {
    if (!mounted || passes <= 0) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (!_scrollController.hasClients ||
          !_scrollController.position.hasContentDimensions) {
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted) _settleAtBottom(passes: passes - 1);
        });
        return;
      }

      final target = _scrollController.position.maxScrollExtent;
      try {
        _scrollController.jumpTo(target);
      } catch (_) {}

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
          _initialScrollDone = true;
          return;
        }
        _settleAtBottom(passes: passes - 1);
      });
    });
  }

  void _handleMessageCountChange(List<Message> messages) {
    final newCount = messages.length;
    if (newCount == _lastMessageCount) return;

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

    final isFirstLoad = !_initialScrollDone;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _lastMessageCount = newCount;
      _lastMessageSignature = newestSignature;

      if (isFirstLoad) {
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

  List<Message>? _lastMessages;

  Widget _buildStream() {
    return AnimatedBuilder(
      animation: BlockService.instance,
      builder: (context, _) => StreamBuilder<List<Message>>(
        stream: widget.messagesStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              _lastMessages == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError && _lastMessages == null) {
            return _buildErrorState(snapshot.error);
          }

          final rawMessages =
              snapshot.data ?? _lastMessages ?? const <Message>[];
          final messages = rawMessages
              .where((m) => !BlockService.instance.isBlocked(m.username))
              .toList();

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
            itemBuilder: (context, index) => MessageBubble(
              message: messages[index],
              onReply: widget.onReply,
            ),
          );
        },
      ),
    );
  }

  // ── Error state ───────────────────────────────────────────────────────────

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
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Text(
        'Nog geen berichten.\nWees de eerste!',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
      ),
    );
  }

  // ── New-messages floating chip ────────────────────────────────────────────

  Widget _buildNewMessagesChip() {
    return Positioned(
      bottom: AppDimensions.paddingMedium,
      left: 0,
      right: 0,
      child: Center(
        child: GestureDetector(
          onTap: () => _scrollToBottom(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.arrow_downward,
                  color: AppColors.textOnDark,
                  size: 14,
                ),
                SizedBox(width: 6),
                Text(
                  'Nieuwe berichten',
                  style: TextStyle(
                    color: AppColors.textOnDark,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
