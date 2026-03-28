/* Message Model
   This file defines the structure of a chat message used in the application.
   
   It describes what data a message contains, such as:
   - the message text 
   - the time it was sent
   - whether the message was sent by the user or by the radio station.
*/

class Message {
  final String role;
  final String text;
  final String time;

  Message({
    required this.role,
    required this.text,
    required this.time,
  });
}