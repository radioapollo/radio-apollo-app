/* Chat Service

   Handles sending and receiving chat messages.

   - Streams the most recent 100 messages from Firestore. The collection
     holds 48h of history (Cloud Function cleanupOldData enforces that),
     and capping the listener at 100 keeps per-listener read costs low
     during busy shows. New connections only pull the recent window
     instead of the entire 48-hour buffer.
   - Sends user messages via the userSendMessage Cloud Function with
     best-effort App Check (server soft-fails so users on Xiaomi/HyperOS
     where Play Integrity is unreliable can still chat, subject to a
     stricter rate limit)
   - Sends admin messages via the adminSendMessage Cloud Function with
     a session token
   - Exposes remaining cooldown seconds for the UI
   - Forwards unexpected send failures to Crashlytics (CooldownException
     and ProfanityException are expected and not logged).
*/

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:http/http.dart' as http;
import 'package:radio_apollo/services/chat/eula_service.dart';
import '../../models/message.dart';
import '../../utils/date_utils.dart';
import '../../utils/profanity/profanity_filter.dart';
import 'app_check_http.dart';
import 'auth_service.dart';
import 'user_service.dart';

class ChatService {
  final AuthService authService;
  final _db = FirebaseFirestore.instance;

  static const String _collection = 'chat_messages';
  static const int maxMessageLength = 160;
  static const int cooldownSeconds = 3;

  static const int _streamLimit = 100;

  DateTime? _lastMessageSent;

  ChatService({required this.authService});

  // ── Cooldown ──────────────────────────────────────────────────────────────

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
        .orderBy('timestamp', descending: true)
        .limit(_streamLimit)
        .snapshots()
        .map((snap) => _mapSnapshotToMessages(snap).reversed.toList());
  }

  List<Message> _mapSnapshotToMessages(
    QuerySnapshot<Map<String, dynamic>> snap,
  ) {
    final cutoff = DateTime.now().subtract(const Duration(hours: 48));
    final localUsername = UserService.instance.username;
    final isAdmin = authService.isAdmin;

    return snap.docs
        .where((doc) {

          final ts = doc.data()['timestamp'] as Timestamp?;
          if (ts == null) return true;
          return ts.toDate().isAfter(cutoff);
        })
        .map((doc) {
          final data = doc.data();
          final ts = data['timestamp'] as Timestamp?;
          final dt = ts?.toDate() ?? DateTime.now();
          final msgUsername = data['username'] as String? ?? 'Onbekend';
          final role = data['role'] as String? ?? 'user';
          return Message(
            id: doc.id,
            role: role,
            text: data['text'] as String? ?? '',
            time: AppDateUtils.formatTime(dt),
            username: msgUsername,
            isCurrentUser:
                !isAdmin &&
                localUsername != null &&
                msgUsername == localUsername &&
                role != 'admin',
          );
        })
        .toList();
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

  Future<bool> _sendUserMessage(String text) async {
    final username = UserService.instance.username;
    if (username == null || username.isEmpty) {
      throw Exception(
        'Stel eerst een gebruikersnaam in voor je een bericht stuurt.',
      );
    }
    // ─── EULA gate ─────────────────────────────────────────────────────────
    if (!EulaService.instance.hasAccepted) {
      throw Exception(
        'Accepteer eerst de gebruiksvoorwaarden om te kunnen chatten.',
      );
    }

    final claimToken = UserService.instance.claimToken;
    if (claimToken == null || claimToken.isEmpty) {
      throw Exception(
        'Beveiligingstoken ontbreekt. Stel je gebruikersnaam opnieuw in via het profielmenu.',
      );
    }

    final remaining = cooldownRemaining();
    if (remaining > 0) {
      throw CooldownException(remaining);
    }

    if (ProfanityFilter.check(text).isSevere) {
      throw ProfanityException(
        'Dit bericht kan niet worden verzonden. Blijf vriendelijk.',
      );
    }

    try {
      final response = await AppCheckHttp.post('userSendMessage', {
        'username': username,
        'text': text,
        'claimToken': claimToken,
      });

      if (response.statusCode == 429) {
        throw Exception('Je stuurt berichten te snel. Wacht even.');
      }
      if (response.statusCode == 401) {

        throw Exception(
          'Beveiligingstoken ongeldig. Stel je gebruikersnaam opnieuw in via het profielmenu.',
        );
      }
      if (response.statusCode == 400) {
        throw ProfanityException(
          _extractError(response, 'Bericht geweigerd.'),
        );
      }
      if (response.statusCode != 200) {
        throw Exception('Bericht kon niet worden verzonden. Probeer opnieuw.');
      }

      _lastMessageSent = DateTime.now();
      return true;
    } catch (e, st) {

      if (e is! CooldownException && e is! ProfanityException) {
        FirebaseCrashlytics.instance.recordError(
          e,
          st,
          reason: 'ChatService._sendUserMessage',
          fatal: false,
        );
      }
      rethrow;
    }
  }

  Future<bool> _sendAdminMessage(String text) async {
    final token = authService.sessionToken;
    if (token == null) return false;

    try {
      final response = await AppCheckHttp.post('adminSendMessage', {
        'token': token,
        'text': text,
      });

      if (response.statusCode != 200) {
        throw Exception('Bericht kon niet worden verzonden. Probeer opnieuw.');
      }
      return true;
    } catch (e, st) {
      FirebaseCrashlytics.instance.recordError(
        e,
        st,
        reason: 'ChatService._sendAdminMessage',
        fatal: false,
      );
      rethrow;
    }
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  static String _extractError(http.Response response, String fallback) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['error'] is String) return body['error'];
    } catch (_) {}
    return fallback;
  }
}

// ── Custom exceptions ────────────────────────────────────────────────────────

class CooldownException implements Exception {
  final int secondsRemaining;
  CooldownException(this.secondsRemaining);

  @override
  String toString() =>
      'Exception: Wacht nog $secondsRemaining seconde${secondsRemaining != 1 ? 'n' : ''}.';
}

class ProfanityException implements Exception {
  final String message;
  ProfanityException(this.message);

  @override
  String toString() => 'Exception: $message';
}
