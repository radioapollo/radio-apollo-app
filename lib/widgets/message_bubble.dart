/* Message Bubble Widget

  This widget represents a single chat message.

   It displays messages in a bubble format similar
   to messaging apps.
*/

import 'package:flutter/material.dart';
import '../models/message.dart';

class MessageBubble extends StatelessWidget {
  final Message message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(
        top: 6,
        bottom: 6,
        left: message.fromUser ? 80 : 0,
        right: message.fromUser ? 0 : 80,
      ),
      child: Column(
        crossAxisAlignment: message.fromUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: message.fromUser ? const Color(0xFF185ADB) : Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!message.fromUser)
                  Container(
                    margin: const EdgeInsets.only(right: 8, top: 2),
                    child: const Icon(Icons.radio, color: Colors.black54, size: 18),
                  ),
                Expanded(
                  child: Text(
                    message.text,
                    style: TextStyle(
                      color: message.fromUser ? Colors.white : Colors.black87,
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