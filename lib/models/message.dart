/* Message Model

   This file defines the structure of a chat message.

   It contains:
   - the role of the sender (user or admin)
   - the display username (new — shown next to other people's bubbles)
   - the message text
   - the time it was sent (formatted HH:mm string)
*/

class Message {
  final String  role;
  final String  text;
  final String  time;
  final String? username;     // display name shown above other people's bubbles
  final bool    isCurrentUser; // true when this message was sent by this device

  const Message({
    required this.role,
    required this.text,
    required this.time,
    this.username,
    this.isCurrentUser = false,
  });
}