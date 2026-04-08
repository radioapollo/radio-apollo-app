/* Chat Service

   Manages chat messages with Firestore.

   It handles:
   - streaming live messages from the last 24 hours, oldest first
   - sending new messages with the correct username and role
   - enforcing the 160 character limit

   Firestore collection: 'chat_messages'
   Document fields: { username, text, role, timestamp }
*/

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message.dart';
import '../utils/date_utils.dart';
import 'auth_service.dart';
import 'user_service.dart';

class ChatService {
  final AuthService authService;
  final _db = FirebaseFirestore.instance;

  static const String _collection  = 'chat_messages';
  static const int    maxMessageLength = 160;

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

  /// Returns false when text is empty or exceeds [maxMessageLength].
  Future<bool> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || trimmed.length > maxMessageLength) return false;

    final username = authService.isAdmin
        ? 'Radio Apollo'
        : (UserService.instance.username ?? 'Onbekend');

    await _db.collection(_collection).add({
      'username':  username,
      'text':      trimmed,
      'role':      authService.currentRole,
      'timestamp': FieldValue.serverTimestamp(),
    });

    return true;
  }
}