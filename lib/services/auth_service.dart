/* Auth Service

   Manages authentication state for the current session.

   It handles:
   - tracking whether the current user is a regular user or admin
   - sending the password to the Cloud Function for verification
   - logging out by resetting the role to user
*/

import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  static const _projectId = 'radio-apollo-90693';
  static const _region    = 'europe-west1';

  String _role = 'user';

  // ── Getters ───────────────────────────────────────────────────────────────

  String get currentRole => _role;
  bool   get isAdmin     => _role == 'admin';

  // ── Login / logout ────────────────────────────────────────────────────────

  Future<void> login(String password) async {
    final uri = Uri.parse(
      'https://$_region-$_projectId.cloudfunctions.net/adminLogin',
    );

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'password': password}),
    );

    if (response.statusCode == 200) {
      _role = 'admin';
    } else {
      _role = 'user';
      throw Exception('Invalid password');
    }
  }

  void logout() => _role = 'user';
}