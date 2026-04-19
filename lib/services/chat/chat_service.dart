/* Chat Service

   Handles sending and receiving chat messages.

   It handles:
   - streaming messages from Firestore (last 24 hours)
   - sending user messages directly to Firestore with a client-side cooldown
   - sending admin messages via the Cloud Function using the session token
   - mapping Firestore exceptions to user-friendly error messages
   - exposing remaining cooldown seconds so the UI can render a countdown
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

  static const String _collection       = 'chat_messages';
  static const int    maxMessageLength  = 160;
  static const int    cooldownSeconds   = 3;

  DateTime? _lastMessageSent;

  ChatService({required this.authService});

  // ── Cooldown helpers ──────────────────────────────────────────────────────

  /// Number of seconds left before the user may send another message.
  /// Returns 0 when no cooldown is active.
  int cooldownRemaining() {
    if (_lastMessageSent == null) return 0;
    final elapsed = DateTime.now().difference(_lastMessageSent!).inSeconds;
    final remaining = cooldownSeconds - elapsed;
    return remaining > 0 ? remaining : 0;
  }

  // ── Stream ────────────────────────────────────────────────────────────────

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
                if (ts == null) return true;
                return ts.toDate().isAfter(cutoff);
              })
              .map((doc) {
                final data          = doc.data();
                final ts            = data['timestamp'] as Timestamp?;
                final dt            = ts?.toDate() ?? DateTime.now();
                final msgUsername   = data['username'] as String? ?? 'Onbekend';
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

  // ── User message ──────────────────────────────────────────────────────────

  Future<bool> _sendUserMessage(String text) async {
    final username = UserService.instance.username;
    if (username == null || username.isEmpty) {
      throw Exception('Stel eerst een gebruikersnaam in voor je een bericht stuurt.');
    }

    final remaining = cooldownRemaining();
    if (remaining > 0) {
      throw CooldownException(remaining);
    }

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

  // ── Admin message ─────────────────────────────────────────────────────────

  Future<bool> _sendAdminMessage(String text) async {
    final token = authService.sessionToken;
    if (token == null) return false;

    final uri = Uri.parse(AppConstants.cloudFunctionUrl('adminSendMessage'));

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

    if (response.statusCode != 200) {
      throw Exception('Bericht kon niet worden verzonden. Probeer opnieuw.');
    }

    return true;
  }
}

// ── Cooldown exception ──────────────────────────────────────────────────────
class CooldownException implements Exception {
  final int secondsRemaining;

  const CooldownException(this.secondsRemaining);

  @override
  String toString() =>
      'Wacht $secondsRemaining seconden voor je nog een bericht stuurt.';
}