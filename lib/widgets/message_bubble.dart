/* Message Bubble Widget

   This widget displays a single chat message as a styled bubble.

   It adapts its appearance based on the sender role:
   - admin messages appear in orange with a radio icon
   - user messages appear in blue, aligned to the right
   - other roles appear in white, aligned to the left

   When a username is present on a non-user bubble,
   it is shown as a small label above the bubble.
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
    // Keep isUser for colour — admin always gets the orange style, current-user
    // gets blue, everyone else gets the neutral white bubble.
    final isUser = isCurrentUser;

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
          // Show the sender's username above other people's bubbles
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
          const SizedBox(height: AppDimensions.spaceXSmall),
          Text(message.time, style: AppTextStyles.bubbleTime),
        ],
      ),
    );
  }
}