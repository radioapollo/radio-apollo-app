/* Auth Service

   Manages authentication state for the current session.

   It handles:
   - tracking whether the current user is a regular user or admin
   - sending the password to the Cloud Function for verification
   - storing the returned session token (never the password)
   - providing the token to ChatService for server-side admin messages
   - logging out by resetting the role and clearing the token

   FIXES APPLIED:
   - HTTP request now has an explicit timeout so a hung function
     server no longer wedges the admin login dialog indefinitely.
   - Uses AppConstants.cloudFunctionUrl() helper — no more duplicated
     URL strings across services.
*/

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../constants/constants.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  String  _role = 'user';
  String? _sessionToken;

  // ── Getters ───────────────────────────────────────────────────────────────

  String  get currentRole  => _role;
  bool    get isAdmin      => _role == 'admin';
  String? get sessionToken => _sessionToken;

  // ── Login / logout ────────────────────────────────────────────────────────

  Future<void> login(String password) async {
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
    } else if (response.statusCode == 429) {
      _role = 'user';
      _sessionToken = null;
      throw Exception('Te veel pogingen. Probeer het over 5 minuten opnieuw.');
    } else {
      _role = 'user';
      _sessionToken = null;
      throw Exception('Invalid password');
    }
  }

  void logout() {
    _role = 'user';
    _sessionToken = null;
  }
}