/* Message Model

   This file defines the structure of a chat message.

   Core fields:
   - id              Firestore document id (used for replies/reports/likes)
   - role            'user' or 'admin'
   - text            the message body
   - time            formatted HH:mm string
   - username        sender display name
   - isCurrentUser   whether this device sent it

   Engagement fields (added with chat actions feature):
   - likes           total like count
   - likedByMe       whether the local user has liked this message
   - replyCount      number of replies pointing at this message
   - replyTo         small embedded snapshot of the message being replied
                     to, if any. We embed instead of resolving by id so a
                     deleted parent still leaves the reply readable.
*/

class ReplyPreview {
  final String? messageId;
  final String username;
  final String textPreview;

  const ReplyPreview({
    this.messageId,
    required this.username,
    required this.textPreview,
  });
}

class Message {
  final String? id;
  final String role;
  final String text;
  final String time;
  final String? username;
  final bool isCurrentUser;

  final int likes;
  final bool likedByMe;
  final int replyCount;
  final ReplyPreview? replyTo;

  const Message({
    this.id,
    required this.role,
    required this.text,
    required this.time,
    this.username,
    this.isCurrentUser = false,
    this.likes = 0,
    this.likedByMe = false,
    this.replyCount = 0,
    this.replyTo,
  });
}