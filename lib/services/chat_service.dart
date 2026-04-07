/* Chat Service

   This service manages chat messages.

   It handles:
   - streaming live messages from Firestore (last 24 hours only)
   - sending new messages with username, text, and timestamp
   - enforcing a 160 character limit on outgoing messages

   The existing AuthService is still accepted in the constructor
   so that the rest of the app does not need to change.

   Firestore collection: 'chat_messages'
   Each document: { username, text, timestamp, role }
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
  static const int maxMessageLength = 160;

  ChatService({required this.authService});

  // ── Firestore stream ──────────────────────────────────────────────────────

  /// Live stream of messages from the last 24 hours, oldest first.
  /// Each item maps directly to the existing [Message] model so nothing
  /// else in the UI needs to change.
  Stream<List<Message>> get messagesStream {
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));

    return _db
        .collection(_collection)
        .where('timestamp', isGreaterThan: Timestamp.fromDate(cutoff))
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final data = doc.data();
              final ts   = data['timestamp'] as Timestamp?;
              final dt   = ts?.toDate() ?? DateTime.now();
              return Message(
                role:     data['role']     as String? ?? 'user',
                text:     data['text']     as String? ?? '',
                time:     AppDateUtils.formatTime(dt),
                username: data['username'] as String? ?? 'Onbekend',
              );
            }).toList());
  }

  // ── Send ─────────────────────────────────────────────────────────────────

  /// Sends a message to Firestore.
  /// Returns false when the text is empty or exceeds [maxMessageLength].
  Future<bool> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || trimmed.length > maxMessageLength) return false;

    final username = UserService.instance.username ?? 'Onbekend';
    final role     = authService.currentRole;

    await _db.collection(_collection).add({
      'username':  username,
      'text':      trimmed,
      'role':      role,
      'timestamp': FieldValue.serverTimestamp(),
    });

    return true;
  }
}