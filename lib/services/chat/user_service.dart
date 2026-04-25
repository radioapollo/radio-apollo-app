/* User Service

   Manages the local user identity across app restarts.

   SECURITY: username claims are made via the Cloud Function `claimUsername`
   (not direct Firestore writes). This binds the claim to an App Check
   token so anonymous scripts cannot bulk-register names.

   It handles:
   - loading the saved username from device storage on startup
   - verifying the username still exists in Firestore on init
   - claiming a new username via the claimUsername Cloud Function
   - saving the username locally on the device
*/

import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/constants.dart';

class UserService {
  UserService._();

  static final UserService instance = UserService._();

  static const String _key = 'chat_username';
  final _db = FirebaseFirestore.instance;

  String? _username;

  // ── Getters ───────────────────────────────────────────────────────────────

  String? get username => _username;
  bool get hasUsername => _username != null && _username!.isNotEmpty;

  // ── Storage ───────────────────────────────────────────────────────────────

  /// Loads the saved username and verifies it still exists in Firestore.
  /// If the name is gone (e.g. server-side cleanup or admin removal),
  /// the local copy is cleared so the user is prompted to pick a new one.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved == null || saved.isEmpty) return;

    try {
      final doc = await _db
          .collection('usernames')
          .doc(saved.toLowerCase())
          .get();
      if (doc.exists) {
        _username = saved;
      } else {
        await prefs.remove(_key);
      }
    } catch (_) {
      // Network error — keep local value, best-effort.
      _username = saved;
    }
  }

  /// Claim a new username via the claimUsername Cloud Function.
  /// Throws an Exception with a user-friendly message on failure.
  Future<void> setUsername(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    // ── App Check token ───────────────────────────────────────────────────
    String? appCheckToken;
    try {
      appCheckToken = await FirebaseAppCheck.instance.getToken();
    } catch (_) {
      throw Exception('Kon geen beveiligingstoken ophalen. Probeer opnieuw.');
    }

    // ── Call Cloud Function ───────────────────────────────────────────────
    final uri = Uri.parse(AppConstants.cloudFunctionUrl('claimUsername'));

    late final http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              if (appCheckToken != null) 'X-Firebase-AppCheck': appCheckToken,
            },
            body: jsonEncode({'name': trimmed}),
          )
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw Exception('Server antwoordt niet. Probeer het later opnieuw.');
    } catch (_) {
      throw Exception(
        'Naam kon niet worden opgeslagen. Controleer je netwerk.',
      );
    }

    if (response.statusCode == 409) {
      throw Exception('Deze naam is al in gebruik. Kies een andere.');
    }
    if (response.statusCode == 400) {
      String msg = 'Ongeldige naam.';
      try {
        final body = jsonDecode(response.body);
        if (body is Map && body['error'] is String) msg = body['error'];
      } catch (_) {}
      throw Exception(msg);
    }
    if (response.statusCode == 401) {
      throw Exception('Naam geweigerd. Werk de app bij en probeer opnieuw.');
    }
    if (response.statusCode != 200) {
      throw Exception('Naam kon niet worden opgeslagen. Probeer opnieuw.');
    }

    // ── Persist locally ───────────────────────────────────────────────────
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, trimmed);
    _username = trimmed;
  }
}
