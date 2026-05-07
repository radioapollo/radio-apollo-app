/* User Service

   Manages the local user identity across app restarts.

   Username claims are made via the claimUsername Cloud Function (which
   strictly enforces App Check) so anonymous scripts cannot bulk-register
   names. On startup, if a saved username exists locally but not yet in
   Firestore, init() silently re-claims it. If the name is already taken,
   the local copy is cleared and the user is prompted to pick a new one.
*/

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'app_check_http.dart';

class UserService {
  UserService._();
  static final UserService instance = UserService._();

  static const String _key = 'chat_username';
  static const String _tokenKey = 'chat_claim_token';
  final _db = FirebaseFirestore.instance;

  String? _username;
  String? _claimToken;

  // ── Getters ───────────────────────────────────────────────────────────────

  String? get username => _username;
  bool get hasUsername => _username != null && _username!.isNotEmpty;
  String? get claimToken => _claimToken;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    final savedToken = prefs.getString(_tokenKey);
    if (saved == null || saved.isEmpty) return;

    _claimToken = savedToken;

    DocumentSnapshot<Map<String, dynamic>>? doc;
    try {
      doc = await _db.collection('usernames').doc(saved.toLowerCase()).get();
    } catch (_) {
      _username = saved;
      return;
    }

    final needsReclaim = !doc.exists || _claimToken == null;

    if (!needsReclaim) {
      _username = saved;
      return;
    }

    try {
      final newToken = await _claimViaCloudFunction(saved);
      _username = saved;
      _claimToken = newToken;
      await prefs.setString(_tokenKey, newToken);
    } catch (_) {
      if (!doc.exists) {
        await prefs.remove(_key);
        await prefs.remove(_tokenKey);
        _username = null;
        _claimToken = null;
      } else {
        _username = saved;
      }
    }
  }

  // ── Public API ────────────────────────────────────────────────────────────

  Future<void> setUsername(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    final newToken = await _claimViaCloudFunction(trimmed);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, trimmed);
    await prefs.setString(_tokenKey, newToken);
    _username = trimmed;
    _claimToken = newToken;
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  Future<String> _claimViaCloudFunction(String name) async {
    final response = await AppCheckHttp.post('claimUsername', {
      'name': name,
    }, requireAppCheck: true);

    if (response.statusCode == 200) {
      try {
        final body = jsonDecode(response.body);
        if (body is Map && body['claimToken'] is String) {
          return body['claimToken'] as String;
        }
      } catch (_) {}

      throw Exception('Server gaf geen geldig token terug. Probeer opnieuw.');
    }

    if (response.statusCode == 409) {
      throw Exception('Deze naam is al in gebruik. Kies een andere.');
    }
    if (response.statusCode == 400) {
      throw Exception(_extractError(response, 'Ongeldige naam.'));
    }
    if (response.statusCode == 401) {
      throw Exception('Naam geweigerd. Werk de app bij en probeer opnieuw.');
    }
    throw Exception('Naam kon niet worden opgeslagen. Probeer opnieuw.');
  }

  static String _extractError(http.Response response, String fallback) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['error'] is String) return body['error'];
    } catch (_) {}
    return fallback;
  }
}
