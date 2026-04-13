/* Chat Service

   Manages chat messages with Firestore.

   It handles:
   - streaming live messages from the last 24 hours, oldest first
   - sending user messages directly to Firestore (with client-side cooldown)
   - sending admin messages through a Cloud Function (token-based auth)
   - enforcing the 160 character limit

   User messages are written directly to Firestore because the app
   primarily targets iOS/Android where Cloud Function CORS is not an
   issue. Firestore Security Rules validate every field on write.
   The userSendMessage Cloud Function remains available as a fallback
   and adds server-side rate limiting for web clients.

   Firestore collection: 'chat_messages'
   Document fields: { username, text, role, timestamp }
*/

import 'dart:async';
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
  // The cutoff is recomputed on every snapshot so the 24h window stays fresh
  // even if the chat screen is left open for hours.

  Stream<List<Message>> get messagesStream {
    return _db
        .collection(_collection)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snap) {
          final cutoff = DateTime.now().subtract(const Duration(hours: 24));

          return snap.docs
              .where((doc) {
                final ts = doc.data()['timestamp'] as Timestamp?;
                if (ts == null) return true; // pending server timestamp
                return ts.toDate().isAfter(cutoff);
              })
              .map((doc) {
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
              })
              .toList();
        });
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

    try {
      await _db.collection(_collection).add({
        'username':  username,
        'text':      text,
        'role':      'user',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw Exception('Bericht geweigerd. Probeer opnieuw.');
      }
      throw Exception('Bericht kon niet worden verzonden. Probeer opnieuw.');
    } catch (_) {
      throw Exception('Bericht kon niet worden verzonden. Controleer je netwerk.');
    }

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

    late final http.Response response;
    try {
      response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'token': token,
          'text':  text,
        }),
      );
    } catch (_) {
      throw Exception('Bericht kon niet worden verzonden. Controleer je netwerk.');
    }

    if (response.statusCode == 401) {
      authService.logout();
      throw Exception('Sessie verlopen. Log opnieuw in.');
    }

    if (response.statusCode != 200) {
      throw Exception('Bericht kon niet worden verzonden. Probeer opnieuw.');
    }

    return true;
  }
}