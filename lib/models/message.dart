/* Message Model

   This file defines the structure of a chat message.

   It contains:
   - the role of the sender (user or admin)
   - the display username
   - the message text
   - the time it was sent (formatted HH:mm string)
   - whether this device was the sender
*/

class Message {
  final String  role;
  final String  text;
  final String  time;
  final String? username;
  final bool    isCurrentUser;

  const Message({
    required this.role,
    required this.text,
    required this.time,
    this.username,
    this.isCurrentUser = false,
  });
}