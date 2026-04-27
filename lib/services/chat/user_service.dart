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
  final _db = FirebaseFirestore.instance;

  String? _username;

  // ── Getters ───────────────────────────────────────────────────────────────

  String? get username => _username;
  bool get hasUsername => _username != null && _username!.isNotEmpty;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved == null || saved.isEmpty) return;

    DocumentSnapshot<Map<String, dynamic>>? doc;
    try {
      doc = await _db.collection('usernames').doc(saved.toLowerCase()).get();
    } catch (_) {
      // Network error — keep the local value, best-effort.
      _username = saved;
      return;
    }

    if (doc.exists) {
      _username = saved;
      return;
    }

    // Saved locally but no Firestore doc yet — try to claim it transparently.
    try {
      await _claimViaCloudFunction(saved);
      _username = saved;
    } catch (_) {
      await prefs.remove(_key);
      _username = null;
    }
  }

  // ── Public API ────────────────────────────────────────────────────────────

  Future<void> setUsername(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    await _claimViaCloudFunction(trimmed);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, trimmed);
    _username = trimmed;
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  /// Throws an Exception with a user-friendly message on failure.
  Future<void> _claimViaCloudFunction(String name) async {
    final response = await AppCheckHttp.post(
      'claimUsername',
      {'name': name},
      requireAppCheck: true,
    );

    if (response.statusCode == 200) return;

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