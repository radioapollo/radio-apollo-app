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

   No preview text — just whose message is being replied to.

   Action row (chat-actions feature)
   ─────────────────────────────────
   Inside non-own bubbles we render up to three small icon buttons
   under the message text:

   - 👍 like with running count
   - 💬 reply with reply count
   - 🚩 flag → opens FlagMenu with Block and Report options

   Visibility rules:
   - Like + reply are visible to everyone (including admins) on
     non-own, non-Studio messages.
   - Like + reply are hidden on the user's own pre-admin messages
     (you can't like yourself).
   - Flag is hidden from Studio messages and from admin viewers
     (admins moderate via long-press, not by flagging).

   Identity for likes
   ──────────────────
   The like is attributed to whichever identity the viewer is in
   RIGHT NOW:
   - As a regular user → `likedBy.<username>` (LikeService.toggleLike)
   - As an admin       → `likedBy.Studio`     (LikeService.toggleStudioLike)

   The two are independent. Admin Raf can have liked a message as
   Raf (filled heart when not in admin mode) and also need to
   separately like it as Studio (outline heart in admin mode until
   tapped). The total count reflects both. Logging out of admin
   doesn't remove the Studio like; it persists until an admin
   untaps it.

   Long-press behaviour
   ────────────────────
   Long-press opens MessageActionsSheet. For every user the sheet
   shows a "Kopiëren" option that copies the message text. For
   admins it additionally shows moderation actions.
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
  // The visible like state depends on which identity the viewer is
  // currently in. We compute it from the right field on the message
  // and re-compute on rebuild so logging in/out of admin flips the
  // heart correctly without needing a restart.
  late bool _likedAsCurrentIdentity = _resolveLikedForViewer(widget.message);
  late int _likes = widget.message.likes;
  bool _likeBusy = false;

  bool _resolveLikedForViewer(Message m) {
    return AuthService.instance.isAdmin ? m.likedByStudio : m.likedByMe;
  }

  @override
  void didUpdateWidget(covariant MessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_likeBusy) {
      _likedAsCurrentIdentity = _resolveLikedForViewer(widget.message);
      _likes = widget.message.likes;
    }
  }

  bool get _hasUsername => UserService.instance.hasUsername;
  bool get _isAdminViewer => AuthService.instance.isAdmin;

  /// True when this message was sent by the local user under their
  /// regular (non-admin) username. Matters because `Message.isCurrentUser`
  /// is hard-coded to false when the viewer is admin (to preserve the
  /// other-people bubble layout), but we still need to know "is this MY
  /// own message" to hide the like/reply row on it.
  bool get _isLocalUserMessage {
    final local = UserService.instance.username;
    return local != null &&
        widget.message.username == local &&
        widget.message.role != 'admin';
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final isCurrentUser = message.isCurrentUser;
    final isAdminMessage = message.role == 'admin';
    final isUser = isCurrentUser;

    // Show the like/reply/flag row when:
    //  - It's NOT the local user's own message (no self-likes)
    //  - It's NOT the bubble currently rendered as "yours" (alignment-wise)
    final showActionRow = !isCurrentUser && !_isLocalUserMessage;

    return GestureDetector(
      // Long-press is the standard messaging-app gesture for "do
      // something with this message" — Copy for everyone, plus
      // moderation actions for admins. The sheet itself decides
      // which entries to render based on the viewer's role.
      onLongPress: () => MessageActionsSheet.show(context, message),
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
                isAdmin: isAdminMessage,
                isUser: isUser,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message.replyTo != null)
                    _buildReplyTag(message.replyTo!, isUser, isAdminMessage),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isAdminMessage)
                        Padding(
                          padding: const EdgeInsets.only(right: 8, top: 2),
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
                  if (showActionRow) ...[
                    const SizedBox(height: AppDimensions.spaceXSmall),
                    _buildActionRow(
                      message,
                      isAdminMessage: isAdminMessage,
                      isUser: isUser,
                    ),
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

  Widget _buildReplyTag(ReplyPreview reply, bool isUser, bool isAdmin) {
    // The reply tag is light text on the dark blue "your own" bubble,
    // dark text everywhere else — including the orange Studio bubble,
    // where the original light-white treatment washed out against the
    // orange background. Only the blue user bubble keeps the on-dark
    // colour because that's the only background that genuinely needs it.
    final color = isUser
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
    required bool isAdminMessage,
    required bool isUser,
  }) {
    // Light text/icons only on the dark-blue "your own" bubble. The
    // orange Studio bubble is light enough that dark icons read
    // better than the previous washed-out light treatment, so we
    // treat it the same as a white user bubble.
    final onDark = isUser;

    // Hide the like button on Studio's own posts.
    final showLike = !isAdminMessage;

    // The flag (report/block) button is for users to flag other users.
    // Hidden on Studio messages (admins aren't flagged this way) and
    // hidden from admin viewers (admins moderate via long-press).
    final showFlag = !isAdminMessage && !_isAdminViewer;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showLike)
          _ActionIcon(
            icon: _likedAsCurrentIdentity
                ? Icons.thumb_up
                : Icons.thumb_up_outlined,
            count: _likes,
            onDark: onDark,
            tinted: _likedAsCurrentIdentity,
            onTap: _likeBusy ? null : _onTapLike,
          ),
        if (showLike) const SizedBox(width: 10),
        _ActionIcon(
          icon: Icons.chat_bubble_outline,
          count: message.replyCount,
          onDark: onDark,
          onTap: () => widget.onReply?.call(message),
        ),
        if (showFlag) ...[
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

    if (!_isAdminViewer && !_hasUsername) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stel eerst een gebruikersnaam in om te liken.'),
        ),
      );
      return;
    }

    final wasLiked = _likedAsCurrentIdentity;
    final wasCount = _likes;

    setState(() {
      _likedAsCurrentIdentity = !wasLiked;
      _likes = wasLiked ? (wasCount - 1).clamp(0, 1 << 31) : wasCount + 1;
      _likeBusy = true;
    });

    try {
      if (_isAdminViewer) {
        await LikeService.instance.toggleStudioLike(message.id!);
      } else {
        await LikeService.instance.toggleLike(message.id!);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _likedAsCurrentIdentity = wasLiked;
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
    // onDark is true only on the dark blue "your own" bubble — see
    // _buildActionRow. On white user bubbles and orange Studio bubbles
    // we want dark icons because the backgrounds are light enough that
    // light icons washed out. So the else branch (dark grey icons) is
    // the right colour for everything that isn't the blue bubble.
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
              const SizedBox(width: 3),
              Text('$count', style: TextStyle(fontSize: 11, color: color)),
            ],
          ],
        ),
      ),
    );
  }
}
