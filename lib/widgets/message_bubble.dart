/* Message Bubble Widget

   This widget displays a single chat message as a styled bubble.

   It adapts its appearance based on the sender role:
   - admin messages appear in orange with a radio icon
   - user messages appear in blue, aligned to the right
   - other roles appear in white, aligned to the left
*/

import 'package:flutter/material.dart';
import '../models/message.dart';

class MessageBubble extends StatelessWidget {
  final Message message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final isAdmin = message.role == 'admin';

    return Container(
      margin: EdgeInsets.only(
        top: 6, bottom: 6,
        left: isUser ? 80 : 0,
        right: isUser ? 0 : 80,
      ),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isAdmin
                  ? Colors.orangeAccent
                  : isUser
                      ? const Color(0xFF185ADB)
                      : Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isAdmin)
                  const Padding(
                    padding: EdgeInsets.only(right: 8, top: 2),
                    child: Icon(Icons.radio, color: Colors.black54, size: 18),
                  ),
                Expanded(
                  child: Text(
                    message.text,
                    style: TextStyle(
                      color: isUser ? Colors.white : Colors.black87,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message.time,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ],
      ),
    );
  }
}