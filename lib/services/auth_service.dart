/* Auth Service

   This service manages authentication state.

   It handles:
   - tracking the current user role
   - admin login and logout

   When Firebase Auth is added later, only this
   file needs to change.
*/

import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  static const _projectId = 'radio-apollo-90693';
  static const _region = 'europe-west1';

  String _role = 'user';

  String get currentRole => _role;

  bool get isAdmin => _role == 'admin';

  Future<void> login(String password) async {
    try {
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
    } catch (e) {
      _role = 'user';
      rethrow;
    }
  }

  void logout() => _role = 'user';
}