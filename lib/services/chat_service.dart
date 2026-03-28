/* Chat Service

   This service manages chat-related functionality.

   It can be used to:
   - store messages
   - send messages
   - retrieve messages from a server (in the future)
*/

import '../models/message.dart';
import '../utils/date_utils.dart';

class ChatService {
  String currentRole = "user";
  final List<Message> _messages = [];

  List<Message> get messages => List.unmodifiable(_messages);

  ChatService() {
    _addInitialMessages();
  }

  void _addInitialMessages() {
    _messages.addAll([
      Message(role: "admin", text: "Welkom bij Radio Apollo! 🎙️", time: "09:12"),
      Message(role: "admin", text: "Wat kan ik voor je doen?", time: "09:12"),
      Message(role: "user", text: "Hey! Ik heb een vraagje 😊", time: "09:13"),
    ]);
  }

  void sendMessage(String text) {
  if (text.trim().isEmpty) return;

  _messages.add(Message(
    role: currentRole,
    text: text.trim(),
    time: AppDateUtils.getCurrentTime(),
    ));
  }

  void loginAsAdmin(String password) {
  if (password == "apollo123") {
    currentRole = "admin";
    }
  }

  void logout() {
    currentRole = "user";
  }
}