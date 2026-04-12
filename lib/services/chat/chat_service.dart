/* Chat Service

   Manages chat messages with Firestore.

   It handles:
   - streaming live messages from the last 24 hours, oldest first
   - sending user messages directly to Firestore (with client-side cooldown)
   - sending admin messages through a Cloud Function (token-based auth)
   - enforcing the 160 character limit

   Firestore collection: 'chat_messages'
   Document fields: { username, text, role, timestamp }
*/

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../../models/message.dart';
import '../../utils/date_utils.dart';
import '../../constants/constants.dart';
import 'auth_service.dart';
import 'user_service.dart';

class ChatService {
  final AuthService authService;
  final _db = FirebaseFirestore.instance;

  static const String _collection      = 'chat_messages';
  static const int    maxMessageLength = 160;
  static const int    _cooldownSeconds = 3;

  DateTime? _lastMessageSent;

  ChatService({required this.authService});

  // ── Stream ────────────────────────────────────────────────────────────────

  Stream<List<Message>> get messagesStream {
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));

    return _db
        .collection(_collection)
        .where('timestamp', isGreaterThan: Timestamp.fromDate(cutoff))
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final data         = doc.data();
              final ts           = data['timestamp'] as Timestamp?;
              final dt           = ts?.toDate() ?? DateTime.now();
              final msgUsername  = data['username'] as String? ?? 'Onbekend';
              final localUsername = UserService.instance.username;
              return Message(
                role:          data['role'] as String? ?? 'user',
                text:          data['text'] as String? ?? '',
                time:          AppDateUtils.formatTime(dt),
                username:      msgUsername,
                isCurrentUser: localUsername != null &&
                    msgUsername == localUsername &&
                    (data['role'] as String? ?? 'user') != 'admin',
              );
            }).toList());
  }

  // ── Send ──────────────────────────────────────────────────────────────────

  Future<bool> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || trimmed.length > maxMessageLength) return false;

    if (authService.isAdmin) {
      return _sendAdminMessage(trimmed);
    }

    return _sendUserMessage(trimmed);
  }

  // ── Private: user message (direct Firestore write with cooldown) ──────────

  Future<bool> _sendUserMessage(String text) async {
    // Client-side cooldown to prevent spam
    if (_lastMessageSent != null) {
      final elapsed = DateTime.now().difference(_lastMessageSent!).inSeconds;
      if (elapsed < _cooldownSeconds) {
        throw Exception(
            'Wacht ${_cooldownSeconds - elapsed} seconden voor je nog een bericht stuurt.');
      }
    }

    final username = UserService.instance.username ?? 'Onbekend';

    await _db.collection(_collection).add({
      'username':  username,
      'text':      text,
      'role':      'user',
      'timestamp': FieldValue.serverTimestamp(),
    });

    _lastMessageSent = DateTime.now();
    return true;
  }

  // ── Private: admin message (via Cloud Function with session token) ────────

  Future<bool> _sendAdminMessage(String text) async {
    final token = authService.sessionToken;
    if (token == null) return false;

    final uri = Uri.parse(
      'https://${AppConstants.region}-${AppConstants.projectId}.cloudfunctions.net/adminSendMessage',
    );

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'token': token,
        'text':  text,
      }),
    );

    if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Sessie verlopen. Log opnieuw in.');
    }

    return response.statusCode == 200;
  }
}