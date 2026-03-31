/*essage Model
 
   This file defines the structure of a chat message.
 
   It contains:
   - the role of the sender (user or admin)
   - the message text
   - the time it was sent
*/
 
class Message {
  final String role;
  final String text;
  final String time;
 
  const Message({
    required this.role,
    required this.text,
    required this.time,
  });
}