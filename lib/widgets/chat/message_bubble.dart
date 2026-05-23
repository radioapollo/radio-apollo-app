/* Message Bubble Widget

   Displays a single chat message as a styled bubble.

   Appearance varies by role:
   - admin  → orange bubble, left-aligned, radio icon, "Radio Apollo" label
   - studio → green bubble, left-aligned, "Studio" label
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
     non-own, non-station messages (station = admin or studio).
   - Like + reply are hidden on the user's own pre-admin messages
     (you can't like yourself).
   - Flag is hidden from station messages and from admin viewers
     (admins moderate via long-press, not by flagging).

   Identity for likes
   ──────────────────
   The like is attributed to whichever identity the viewer is in
   RIGHT NOW:
   - As a regular user → `likedBy.<username>` (LikeService.toggleLike)
   - As an admin       → `likedBy.__admin__`  (LikeService.toggleStudioLike)

   The two are independent. The total count reflects both. Logging out
   of admin doesn't remove the admin like; it persists until an admin
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
    // Studio shares the admin (__admin__) like identity, so a privileged
    // viewer (admin OR studio) reads the same likedByAdmin flag.
    return AuthService.instance.isPrivileged ? m.likedByAdmin : m.likedByMe;
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

  /// True when this message was sent by the local user under their
  /// regular (non-station) username. Matters because `Message.isCurrentUser`
  /// is hard-coded to false when the viewer is privileged (to preserve the
  /// other-people bubble layout), but we still need to know "is this MY
  /// own message" to hide the like/reply row on it.
  bool get _isLocalUserMessage {
    final local = UserService.instance.username;
    return local != null &&
        widget.message.username == local &&
        widget.message.role == 'user';
  }

  /// True when this is a station message (admin/studio) sent by the
  /// SAME identity the viewer currently holds. An admin shouldn't be
  /// able to reply to / like the orange "Radio Apollo" messages they
  /// themselves post, and likewise studio shouldn't act on the green
  /// "Studio" messages. (Cross-identity is still allowed: an admin can
  /// act on a studio message and vice-versa.)
  bool get _isOwnStationMessage {
    final role = widget.message.role;
    if (role == 'admin') return AuthService.instance.isAdmin;
    if (role == 'studio') return AuthService.instance.isStudio;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final isCurrentUser = message.isCurrentUser;
    final isAdminMessage = message.role == 'admin';
    final isStudioMessage = message.role == 'studio';
    final isStationMessage = isAdminMessage || isStudioMessage;
    final isUser = isCurrentUser;

    // Show the like/reply/flag row when it's NOT your own message in any
    // identity: not your regular-user message, not the bubble rendered as
    // "yours", and not a station message from the identity you currently
    // hold (admin viewing Radio Apollo, or studio viewing Studio).
    final showActionRow =
        !isCurrentUser && !_isLocalUserMessage && !_isOwnStationMessage;

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
                role: message.role,
                isUser: isUser,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message.replyTo != null)
                    _buildReplyTag(message.replyTo!, isUser, isStationMessage),
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
                            // Dark text on the light blue "mine" bubble is
                            // white; on the orange admin and green studio
                            // bubbles we also want dark text for contrast;
                            // on the themed surface bubble it's textBody.
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
                      isStationMessage: isStationMessage,
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

  Widget _buildReplyTag(ReplyPreview reply, bool isUser, bool isStation) {
    // Light text only on the dark-blue "your own" bubble. On the orange
    // admin and green studio bubbles (and the themed surface bubble) the
    // background is light enough that dark text reads better.
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
    required bool isStationMessage,
    required bool isUser,
  }) {
    // Light icons only on the dark-blue "your own" bubble. Orange/green
    // station bubbles and white user bubbles get dark icons.
    final onDark = isUser;

    // Hide the like button on station (admin/studio) posts.
    final showLike = !isStationMessage;

    // The flag (report/block) button is for regular users to flag other
    // users. Hidden on station messages and hidden from privileged
    // viewers (admin moderates via long-press; studio isn't a moderator).
    final showFlag = !isStationMessage && !AuthService.instance.isPrivileged;

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

    // Privileged sessions (admin/studio) like via the session-token path
    // and don't need a claimed username. Regular users do.
    final isPrivileged = AuthService.instance.isPrivileged;
    if (!isPrivileged && !_hasUsername) {
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
      if (isPrivileged) {
        // Both admin and studio toggle the shared __admin__ like via
        // the same Cloud Function (adminToggleLike accepts either token).
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
    // onDark is true only on the dark blue "your own" bubble. On white
    // user bubbles and orange/green station bubbles we want dark icons
    // because the backgrounds are light enough that light icons washed
    // out. So the else branch (dark grey icons) is the right colour for
    // everything that isn't the blue bubble.
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
