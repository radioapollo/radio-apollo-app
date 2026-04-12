/* Auth Service

   Manages authentication state for the current session.

   It handles:
   - tracking whether the current user is a regular user or admin
   - sending the password to the Cloud Function for verification
   - storing the returned session token (never the password)
   - providing the token to ChatService for server-side admin messages
   - logging out by resetting the role and clearing the token
*/

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../constants/constants.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  String  _role = 'user';
  String? _sessionToken;   // short-lived token from server, cleared on logout

  // ── Getters ───────────────────────────────────────────────────────────────

  String  get currentRole    => _role;
  bool    get isAdmin        => _role == 'admin';
  String? get sessionToken   => _sessionToken;

  // ── Login / logout ────────────────────────────────────────────────────────

  Future<void> login(String password) async {
    final uri = Uri.parse(
      'https://${AppConstants.region}-${AppConstants.projectId}.cloudfunctions.net/adminLogin',
    );

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'password': password}),
    );

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