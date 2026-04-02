/* Chat Service

   This service manages chat-related functionality.

   It handles:
   - storing and retrieving messages
   - sending new messages

   Authentication is delegated to AuthService.
*/

import '../models/message.dart';
import '../utils/date_utils.dart';
import 'auth_service.dart';

class ChatService {
  final AuthService authService;

  ChatService({required this.authService});

  final List<Message> _messages = [
    const Message(role: 'admin', text: 'Welkom bij Radio Apollo! 🎙️', time: '09:12'),
    const Message(role: 'admin', text: 'Wat kan ik voor je doen?', time: '09:12'),
    const Message(role: 'user', text: 'Hey! Ik heb een vraagje 😊', time: '09:13'),
  ];

  List<Message> get messages => List.unmodifiable(_messages);

  void sendMessage(String text) {
    if (text.trim().isEmpty) return;
    _messages.add(Message(
      role: authService.currentRole,
      text: text.trim(),
      time: AppDateUtils.getCurrentTime(),
    ));
  }
}