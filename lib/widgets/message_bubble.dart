/* Message Bubble Widget

   Displays a single chat message as a styled bubble.

   Appearance varies by role:
   - admin  → orange bubble, left-aligned, radio icon, "Radio Apollo" label
   - own    → blue bubble, right-aligned, no label
   - other  → white bubble, left-aligned, username label above
*/

import 'package:flutter/material.dart';
import '../models/message.dart';
import '../theme/app_theme.dart';

class MessageBubble extends StatelessWidget {
  final Message message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isCurrentUser = message.isCurrentUser;
    final isAdmin       = message.role == 'admin';
    final isUser        = isCurrentUser;

    return Container(
      margin: EdgeInsets.only(
        top:    AppDimensions.spaceSmall,
        bottom: AppDimensions.spaceSmall,
        left:   isCurrentUser ? 80 : 0,
        right:  isCurrentUser ? 0  : 80,
      ),
      child: Column(
        crossAxisAlignment:
            isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // ── Username label above other people's bubbles ──────────────────
          if (!isUser && message.username != null)
            Padding(
              padding: const EdgeInsets.only(
                left:   AppDimensions.spaceSmall,
                bottom: AppDimensions.spaceXSmall,
              ),
              child: Text(
                message.username!,
                style: const TextStyle(
                  color:      Colors.white60,
                  fontSize:   11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

          // ── Bubble ───────────────────────────────────────────────────────
          Container(
            padding:    const EdgeInsets.all(AppDimensions.paddingSmall),
            decoration: AppDecorations.chatBubble(
                isAdmin: isAdmin, isUser: isUser),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isAdmin)
                  const Padding(
                    padding: EdgeInsets.only(right: 8, top: 2),
                    child: Icon(
                      Icons.radio,
                      color: Colors.black54,
                      size:  AppDimensions.iconMedium,
                    ),
                  ),
                Expanded(
                  child: Text(
                    message.text,
                    style: AppTextStyles.bubbleText.copyWith(
                      color: isUser ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Timestamp ────────────────────────────────────────────────────
          const SizedBox(height: AppDimensions.spaceXSmall),
          Text(message.time, style: AppTextStyles.bubbleTime),
        ],
      ),
    );
  }
}