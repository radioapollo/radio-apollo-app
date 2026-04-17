/* Chat Service

   FIXES APPLIED:
   - _sendUserMessage now throws immediately if no username is set,
     instead of falling back to 'Onbekend' (Issue: Messages sent with username Unknown)
   - All Firestore exceptions are caught and replaced with user-friendly
     messages instead of exposing raw error strings (Issue: Technical Firestore error shown to user)
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

  // ── Private: user message ─────────────────────────────────────────────────

  Future<bool> _sendUserMessage(String text) async {
    // FIX: Reject send entirely if no username is set.
    // Prevents messages being written with 'Onbekend' as the username.
    final username = UserService.instance.username;
    if (username == null || username.isEmpty) {
      throw Exception('Stel eerst een gebruikersnaam in voor je een bericht stuurt.');
    }

    // Client-side cooldown to prevent spam
    if (_lastMessageSent != null) {
      final elapsed = DateTime.now().difference(_lastMessageSent!).inSeconds;
      if (elapsed < _cooldownSeconds) {
        throw Exception(
            'Wacht ${_cooldownSeconds - elapsed} seconden voor je nog een bericht stuurt.');
      }
    }

    try {
      await _db.collection(_collection).add({
        'username':  username, // FIX: always a verified username, never 'Onbekend'
        'text':      text,
        'role':      'user',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      // FIX: Catch and replace Firestore error codes with readable messages
      if (e.code == 'permission-denied') {
        throw Exception('Bericht geweigerd. Probeer opnieuw.');
      }
      throw Exception('Bericht kon niet worden verzonden. Probeer opnieuw.');
    } catch (_) {
      // FIX: Catch all other exceptions — never expose raw error strings
      throw Exception('Bericht kon niet worden verzonden. Controleer je netwerk.');
    }

    _lastMessageSent = DateTime.now();
    return true;
  }

  // ── Private: admin message ────────────────────────────────────────────────

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

    if (response.statusCode != 200) {
      throw Exception('Bericht kon niet worden verzonden. Probeer opnieuw.');
    }

    return true;
  }
}