/* User Service

   Manages the local user identity across app restarts.

   SECURITY: username claims are made via the Cloud Function `claimUsername`
   (not direct Firestore writes). This binds the claim to an App Check
   token so anonymous scripts cannot bulk-register names.

   UPGRADE PATH: when a user updates from a pre-security-fix version of
   the app, their saved username may exist in local SharedPreferences but
   not yet in the Firestore `usernames` collection. In that case
   `init()` will silently attempt to re-claim the name on their behalf.
   If the name is still available, the user keeps it transparently.
   If someone else has taken it, the local copy is cleared and the
   user is prompted to pick a new one — same as a fresh install.

   It handles:
   - loading the saved username from device storage on startup
   - verifying the username still exists in Firestore on init
   - auto-reclaiming the saved username if it has no Firestore doc yet
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
  ///
  /// If the name is missing in Firestore (typical for users upgrading from
  /// a pre-security-fix build), tries to re-claim it transparently. Only
  /// if that fails do we clear the local copy and force the user to pick
  /// a new name.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved == null || saved.isEmpty) return;

    DocumentSnapshot<Map<String, dynamic>>? doc;
    try {
      doc = await _db.collection('usernames').doc(saved.toLowerCase()).get();
    } catch (_) {
      // Network error — keep local value, best-effort.
      _username = saved;
      return;
    }

    if (doc.exists) {
      // Already registered — nothing to do.
      _username = saved;
      return;
    }

    // Saved locally but no Firestore doc yet — try to claim it for them.
    try {
      await _claimViaCloudFunction(saved);
      _username = saved;
    } catch (_) {
      // Claim failed (taken by someone else, App Check error, network, ...).
      // Clear the local copy so the UI prompts the user to pick a new name.
      await prefs.remove(_key);
      _username = null;
    }
  }

  /// Claim a new username via the claimUsername Cloud Function.
  /// Throws an Exception with a user-friendly message on failure.
  Future<void> setUsername(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    await _claimViaCloudFunction(trimmed);

    // Persist locally
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, trimmed);
    _username = trimmed;
  }

  // ── Internal: shared HTTP call ────────────────────────────────────────────
  //
  // Throws an Exception on any non-success response. The exception
  // message is suitable for showing directly to the user.

  Future<void> _claimViaCloudFunction(String name) async {
    String? appCheckToken;
    try {
      appCheckToken = await FirebaseAppCheck.instance.getToken();
    } catch (_) {
      throw Exception('Kon geen beveiligingstoken ophalen. Probeer opnieuw.');
    }

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
            body: jsonEncode({'name': name}),
          )
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw Exception('Server antwoordt niet. Probeer het later opnieuw.');
    } catch (_) {
      throw Exception(
        'Naam kon niet worden opgeslagen. Controleer je netwerk.',
      );
    }

    if (response.statusCode == 200) return;

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

    throw Exception('Naam kon niet worden opgeslagen. Probeer opnieuw.');
  }
}
