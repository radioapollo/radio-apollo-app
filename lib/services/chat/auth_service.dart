/* Auth Service

   Manages authentication state for the current session.

   Desktop auto-login
   ──────────────────
   On Windows/Linux/macOS the admin password is saved to
   shared_preferences after a successful login. On the next launch
   tryAutoLogin() is called first — if a saved password exists it logs
   in silently with no dialog. The staff only ever need to type the
   password once.

   The password is stored only in the local app data folder on their PC
   (shared_preferences), never in source code or transmitted anywhere
   except to the Firebase adminLogin Cloud Function over HTTPS.

   On mobile this feature is disabled — shared_preferences is not used
   for auth there.
*/

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/constants.dart';

bool get _isDesktop =>
    !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  static const _savedPasswordKey = 'admin_saved_password';

  String _role = 'user';
  String? _sessionToken;

  // ── Getters ───────────────────────────────────────────────────────────────

  String get currentRole => _role;
  bool get isAdmin => _role == 'admin';
  String? get sessionToken => _sessionToken;

  // ── Desktop auto-login ────────────────────────────────────────────────────

  /// Attempts a silent login using a previously saved password.
  /// Returns true if login succeeded, false otherwise.
  /// Only does anything on desktop; no-op on mobile/web.
  Future<bool> tryAutoLogin() async {
    if (!_isDesktop) return false;

    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_savedPasswordKey);
    if (saved == null || saved.isEmpty) return false;

    try {
      await login(saved, persist: false); // already persisted
      return true;
    } catch (_) {
      // Saved password no longer valid (e.g. password was changed).
      // Clear it so the manual dialog shows next time.
      await prefs.remove(_savedPasswordKey);
      return false;
    }
  }

  /// Clears the saved password (call when staff want to log out permanently).
  Future<void> clearSavedPassword() async {
    if (!_isDesktop) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_savedPasswordKey);
  }

  // ── Login / logout ────────────────────────────────────────────────────────

  Future<void> login(String password, {bool persist = true}) async {
    final uri = Uri.parse(AppConstants.cloudFunctionUrl('adminLogin'));

    late final http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'password': password}),
          )
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      _role = 'user';
      _sessionToken = null;
      throw Exception('Server antwoordt niet. Probeer het later opnieuw.');
    } catch (_) {
      _role = 'user';
      _sessionToken = null;
      throw Exception('Controleer je netwerkverbinding en probeer opnieuw.');
    }

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      _role = 'admin';
      _sessionToken = body['token'] as String?;

      // Save password on desktop so next launch is automatic.
      if (_isDesktop && persist) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_savedPasswordKey, password);
      }
    } else if (response.statusCode == 429) {
      _role = 'user';
      _sessionToken = null;
      throw Exception('Te veel pogingen. Probeer het over 5 minuten opnieuw.');
    } else {
      _role = 'user';
      _sessionToken = null;
      throw Exception('Wachtwoord is niet juist.');
    }
  }

  void logout() {
    _role = 'user';
    _sessionToken = null;
  }
}