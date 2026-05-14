/* User Service

   Manages the local user identity across app restarts.

   Username claims are made via the claimUsername Cloud Function (which
   strictly enforces App Check) so anonymous scripts cannot bulk-register
   names. On startup, if a saved username exists locally but not yet in
   Firestore, init() silently re-claims it. If the name is already taken,
   the local copy is cleared and the user is prompted to pick a new one.

   ─── Fast init vs background re-claim ──────────────────────────────────────
   `init()` is on the critical cold-start path — the chat screen renders
   immediately after `runApp()` and reads `hasUsername` synchronously. If
   that returns `false` because init hasn't finished yet, the user sees
   the "Kies een naam om mee te chatten" prompt even though they already
   have a name saved. That looks like data loss.

   To prevent it, `init()` is split into two phases:

     1. Fast: read SharedPreferences (local, ~1ms). Set `_username` and
        `_claimToken` immediately so `hasUsername` returns true. No
        network. This must complete before `runApp()`.

     2. Slow: verify the username doc in Firestore, and re-claim via
        the Cloud Function if the doc is missing or the token is
        unrecognised. Network round-trips that should never block the
        first frame.

   The slow phase runs as a fire-and-forget Future kicked off at the
   end of the fast phase. If the re-claim fails because the name was
   stolen by someone else, `_username` and `_claimToken` get cleared
   and the chat screen will re-render the "pick a name" prompt — but
   that's the right outcome in that case, and it's rare enough that
   the brief flash of the username doesn't mislead the user.
*/

import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
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
  bool _initialised = false;

  // ── Getters ───────────────────────────────────────────────────────────────

  String? get username => _username;
  bool get hasUsername => _username != null && _username!.isNotEmpty;
  String? get claimToken => _claimToken;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Fast, local-only init. Reads the saved username and token from
  /// SharedPreferences so the UI can render the right state on the
  /// first frame. Schedules the slow Firestore + Cloud Function
  /// verification to run in the background; callers do NOT need to
  /// await it.
  ///
  /// Idempotent: calling init() more than once is a no-op (the chat
  /// screen calls it defensively from `_ensureUsername`, but main()
  /// has already run it on the critical path).
  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;

    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    final savedToken = prefs.getString(_tokenKey);
    if (saved == null || saved.isEmpty) return;

    _username = saved;
    _claimToken = savedToken;

    // Kick off the verification/re-claim in the background. We don't
    // await it: the UI already has what it needs.
    unawaited(_verifyAndReclaimIfNeeded(saved, savedToken));
  }

  Future<void> _verifyAndReclaimIfNeeded(
    String saved,
    String? savedToken,
  ) async {
    DocumentSnapshot<Map<String, dynamic>>? doc;
    try {
      doc = await _db.collection('usernames').doc(saved.toLowerCase()).get();
    } catch (e) {
      // Network failure during verification — keep the optimistic
      // local state and try again next launch.
      debugPrint('[UserService] Verification fetch failed: $e');
      return;
    }

    final needsReclaim = !doc.exists || savedToken == null;
    if (!needsReclaim) return;

    try {
      final newToken = await _claimViaCloudFunction(saved);
      _claimToken = newToken;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, newToken);
    } catch (e) {
      debugPrint('[UserService] Re-claim failed: $e');
      // If the username doc still doesn't exist (i.e. someone took the
      // name on another device), clear the local state so the user is
      // prompted to pick a new one next time they try to chat.
      if (!doc.exists) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_key);
        await prefs.remove(_tokenKey);
        _username = null;
        _claimToken = null;
      }
      // Otherwise (doc exists but re-claim failed for network/server
      // reasons), keep the local state and try again next launch.
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