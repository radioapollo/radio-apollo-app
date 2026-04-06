/* Chat Service

   This service manages chat messages via Firestore.

   It handles:
   - streaming messages from the last 24 hours in real time
   - sending new messages with username + timestamp
   - enforcing a 160 character limit

   Firestore collection: 'chat_messages'
   Each document: { username, text, timestamp }

   Old messages (>24h) are filtered out on read.
   You can set up a Cloud Function later to auto-delete them server-side.
*/

import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_service.dart';

class ChatService {
  final _db = FirebaseFirestore.instance;
  static const String _collection = 'chat_messages';
  static const int maxMessageLength = 160;

  /// Stream of messages from the last 24 hours, ordered oldest-first.
  Stream<List<Map<String, dynamic>>> get messagesStream {
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    return _db
        .collection(_collection)
        .where('timestamp', isGreaterThan: Timestamp.fromDate(cutoff))
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  'username': doc['username'] as String? ?? 'Onbekend',
                  'text': doc['text'] as String? ?? '',
                  'timestamp': (doc['timestamp'] as Timestamp).toDate(),
                })
            .toList());
  }

  /// Sends a message. Returns false if text is empty or too long.
  Future<bool> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || trimmed.length > maxMessageLength) return false;

    final username = UserService.instance.username ?? 'Onbekend';

    await _db.collection(_collection).add({
      'username': username,
      'text': trimmed,
      'timestamp': FieldValue.serverTimestamp(),
    });

    return true;
  }
}