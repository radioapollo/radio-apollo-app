/* Chat Service (with Profanity Filter)

   Handles sending and receiving chat messages.

   SECURITY: user messages are sent via the Cloud Function `userSendMessage`
   instead of writing directly to Firestore. This ensures rate limiting,
   profanity enforcement, and App Check validation all run server-side.
   Direct Firestore writes are blocked by security rules.

   Client-side profanity check remains for instant feedback, but the
   server performs the authoritative check.

   Features:
   - streaming messages from Firestore (last 24 hours)
   - sending user messages via the userSendMessage Cloud Function
   - sending admin messages via the adminSendMessage Cloud Function
   - mapping HTTP errors to user-friendly messages
   - exposing remaining cooldown seconds so the UI can render a countdown
*/

import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:http/http.dart' as http;
import '../../models/message.dart';
import '../../utils/date_utils.dart';
import '../../utils/profanity/profanity_filter.dart';
import '../../constants/constants.dart';
import 'auth_service.dart';
import 'user_service.dart';

class ChatService {
  final AuthService authService;
  final _db = FirebaseFirestore.instance;

  static const String _collection = 'chat_messages';
  static const int maxMessageLength = 160;
  static const int cooldownSeconds = 3;

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
                final data = doc.data();
                final ts = data['timestamp'] as Timestamp?;
                final dt = ts?.toDate() ?? DateTime.now();
                final msgUsername = data['username'] as String? ?? 'Onbekend';
                final localUsername = UserService.instance.username;
                return Message(
                  role: data['role'] as String? ?? 'user',
                  text: data['text'] as String? ?? '',
                  time: AppDateUtils.formatTime(dt),
                  username: msgUsername,
                  isCurrentUser:
                      localUsername != null &&
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
      throw Exception(
        'Stel eerst een gebruikersnaam in voor je een bericht stuurt.',
      );
    }

    final remaining = cooldownRemaining();
    if (remaining > 0) {
      throw CooldownException(remaining);
    }

    // ── Client-side profanity check (instant UX, server re-checks) ────────
    final filterResult = ProfanityFilter.check(text);

    if (filterResult.isSevere) {
      throw ProfanityException(
        'Dit bericht kan niet worden verzonden. Blijf vriendelijk.',
      );
    }

    // ── App Check token ───────────────────────────────────────────────────
    // The Cloud Function rejects requests without a valid App Check token,
    // proving the call comes from a genuine build of this app.
    String? appCheckToken;
    try {
      appCheckToken = await FirebaseAppCheck.instance.getToken();
    } catch (_) {
      throw Exception('Bericht kon niet worden verzonden. Probeer opnieuw.');
    }

    // ── Send via Cloud Function ───────────────────────────────────────────
    final uri = Uri.parse(AppConstants.cloudFunctionUrl('userSendMessage'));

    late final http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              if (appCheckToken != null) 'X-Firebase-AppCheck': appCheckToken,
            },
            body: jsonEncode({'username': username, 'text': text}),
          )
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw Exception('Server antwoordt niet. Probeer het later opnieuw.');
    } catch (_) {
      throw Exception(
        'Bericht kon niet worden verzonden. Controleer je netwerk.',
      );
    }

    if (response.statusCode == 429) {
      throw Exception('Je stuurt berichten te snel. Wacht even.');
    }
    if (response.statusCode == 400) {
      // Server rejected (length / profanity / unknown username)
      String msg = 'Bericht geweigerd.';
      try {
        final body = jsonDecode(response.body);
        if (body is Map && body['error'] is String) msg = body['error'];
      } catch (_) {}
      throw ProfanityException(msg);
    }
    if (response.statusCode == 401) {
      throw Exception('Bericht geweigerd. Werk de app bij en probeer opnieuw.');
    }
    if (response.statusCode != 200) {
      throw Exception('Bericht kon niet worden verzonden. Probeer opnieuw.');
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
        body: jsonEncode({'token': token, 'text': text}),
      );
    } catch (_) {
      throw Exception(
        'Bericht kon niet worden verzonden. Controleer je netwerk.',
      );
    }

    if (response.statusCode != 200) {
      throw Exception('Bericht kon niet worden verzonden. Probeer opnieuw.');
    }

    return true;
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
