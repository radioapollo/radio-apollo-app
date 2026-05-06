/* Message Bubble Widget

   Displays a single chat message as a styled bubble.

   Appearance varies by role:
   - admin  → orange bubble, left-aligned, radio icon, "Radio Apollo" label
   - own    → blue bubble, right-aligned, no label
   - other  → white bubble, left-aligned, username label above

   Reply tag (compact)
   ───────────────────
   When a message is a reply, we show a single-line tag at the top of
   the bubble:

      ↩ Antwoord aan Logru

   No preview text — just whose message is being replied to. This
   keeps bubbles compact even when many people reply to the same
   message. The reply count next to the parent's 💬 icon does the
   "how active is this thread" signaling.

   Action row (chat-actions feature)
   ─────────────────────────────────
   Inside every non-own bubble we render up to three small icon
   buttons under the message text:

   - 👍 like with running count
   - 💬 reply with reply count
   - 🚩 flag (hidden on admin messages) → opens FlagMenu with
        Block and Report options

   Long-press behaviour
   ────────────────────
   Long-press is reserved for ADMIN moderation actions (delete
   message, ban user). For non-admin users it's a no-op.
*/

import 'package:flutter/material.dart';
import '../../models/message.dart';
import '../../services/chat/auth_service.dart';
import '../../services/chat/like_service.dart';
import '../../services/chat/user_service.dart';
import '../../theme/app_theme.dart';
import 'flag_menu.dart';
import 'message_actions_sheet.dart';

class MessageBubble extends StatefulWidget {
  final Message message;
  final ValueChanged<Message>? onReply;

  const MessageBubble({super.key, required this.message, this.onReply});

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  late bool _likedByMe = widget.message.likedByMe;
  late int _likes = widget.message.likes;
  bool _likeBusy = false;

  @override
  void didUpdateWidget(covariant MessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_likeBusy) {
      _likedByMe = widget.message.likedByMe;
      _likes = widget.message.likes;
    }
  }

  bool get _hasUsername => UserService.instance.hasUsername;
  bool get _isAdminViewer => AuthService.instance.isAdmin;

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final isCurrentUser = message.isCurrentUser;
    final isAdmin = message.role == 'admin';
    final isUser = isCurrentUser;

    return GestureDetector(
      onLongPress: _isAdminViewer
          ? () => MessageActionsSheet.show(context, message)
          : null,
      child: Container(
        margin: EdgeInsets.only(
          top: AppDimensions.spaceSmall,
          bottom: AppDimensions.spaceSmall,
          left: isCurrentUser ? 80 : 0,
          right: isCurrentUser ? 0 : 80,
        ),
        child: Column(
          crossAxisAlignment: isCurrentUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            // ── Username label above other people's bubbles ────────────────
            if (!isUser && message.username != null)
              Padding(
                padding: const EdgeInsets.only(
                  left: AppDimensions.spaceSmall,
                  bottom: AppDimensions.spaceXSmall,
                ),
                child: Text(
                  message.username!,
                  style: const TextStyle(
                    color: AppColors.usernameLabel,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

            // ── Bubble ─────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.paddingSmall,
                AppDimensions.paddingSmall,
                AppDimensions.paddingSmall,
                AppDimensions.spaceXSmall,
              ),
              decoration: AppDecorations.chatBubble(
                isAdmin: isAdmin,
                isUser: isUser,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message.replyTo != null)
                    _buildReplyTag(message.replyTo!, isUser, isAdmin),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isAdmin)
                        Padding(
                          padding: EdgeInsets.only(right: 8, top: 2),
                          child: Icon(
                            Icons.radio,
                            color: AppColors.textSecondary,
                            size: AppDimensions.iconMedium,
                          ),
                        ),
                      Expanded(
                        child: Text(
                          message.text,
                          style: AppTextStyles.bubbleText.copyWith(
                            color: isUser
                                ? AppColors.textOnDark
                                : AppColors.textBody,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Hide the action row from:
                  // - the sender themselves (no point liking your own message)
                  // - admin viewers (admin uses long-press for moderation;
                  //   likes/replies/flags are user-facing and shouldn't apply
                  //   to the studio role)
                  if (!isCurrentUser && !_isAdminViewer) ...[
                    const SizedBox(height: AppDimensions.spaceXSmall),
                    _buildActionRow(message, isAdmin: isAdmin, isUser: isUser),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Compact reply tag ────────────────────────────────────────────────────
  //
  // Single line of muted text at the top of replies. No preview content —
  // only the username, with a curly arrow icon to convey "this is a reply
  // to X". Total height adds maybe 16px instead of the 40+ a preview chip
  // would.

  Widget _buildReplyTag(ReplyPreview reply, bool isUser, bool isAdmin) {
    final onDark = isUser || isAdmin;
    final color = onDark
        ? AppColors.textOnDark.withValues(alpha: 0.7)
        : AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.subdirectory_arrow_right, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              'Antwoord aan ${reply.username}',
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ── Action row ──────────────────────────────────────────────────────────

  Widget _buildActionRow(
    Message message, {
    required bool isAdmin,
    required bool isUser,
  }) {
    final onDark = isUser || isAdmin;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ActionIcon(
          icon: _likedByMe ? Icons.thumb_up : Icons.thumb_up_outlined,
          count: _likes,
          onDark: onDark,
          tinted: _likedByMe,
          onTap: _likeBusy ? null : _onTapLike,
        ),
        const SizedBox(width: 10),
        _ActionIcon(
          icon: Icons.chat_bubble_outline,
          count: message.replyCount,
          onDark: onDark,
          onTap: () => widget.onReply?.call(message),
        ),
        if (!isAdmin) ...[
          const SizedBox(width: 10),
          _ActionIcon(
            icon: Icons.flag_outlined,
            onDark: onDark,
            onTap: () => FlagMenu.show(context, message),
          ),
        ],
      ],
    );
  }

  // ── Like handler ────────────────────────────────────────────────────────

  Future<void> _onTapLike() async {
    final message = widget.message;
    if (message.id == null) return;

    if (!_hasUsername) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stel eerst een gebruikersnaam in om te liken.'),
        ),
      );
      return;
    }

    final wasLiked = _likedByMe;
    final wasCount = _likes;

    setState(() {
      _likedByMe = !wasLiked;
      _likes = wasLiked ? (wasCount - 1).clamp(0, 1 << 31) : wasCount + 1;
      _likeBusy = true;
    });

    try {
      await LikeService.instance.toggleLike(message.id!);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _likedByMe = wasLiked;
        _likes = wasCount;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _likeBusy = false);
    }
  }
}

// ── Single icon-with-optional-count button ──────────────────────────────────

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final int? count;
  final bool tinted;
  final bool onDark;
  final VoidCallback? onTap;

  const _ActionIcon({
    required this.icon,
    this.count,
    this.tinted = false,
    this.onDark = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color color;
    if (tinted) {
      color = onDark ? AppColors.textOnDark : AppColors.primaryLight;
    } else {
      color = onDark
          ? AppColors.textOnDark.withValues(alpha: 0.6)
          : AppColors.textSecondary.withValues(alpha: 0.7);
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            if (count != null && count! > 0) ...[
              const SizedBox(width: 4),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}