/* Auth Service

   Manages authentication state for the current session.

   Roles
   ─────
   - 'user'   : the default — a regular chatter (or nobody logged in)
   - 'admin'  : full moderation, posts as "Radio Apollo" (orange)
   - 'studio' : posts/replies only, no moderation, posts as "Studio" (green)

   There is ONE login screen. The user types one password; the server
   (adminLogin) checks it against config/admin then config/studio and
   returns { token, role }. We store whichever role came back. The app
   never knows or stores the password — only the session token.

   It handles:
   - tracking whether the current session is user / admin / studio
   - sending the password to the Cloud Function for verification
   - storing the returned session token (never the password)
   - providing the token to ChatService for server-side admin/studio sends
   - logging out by resetting the role and clearing the token
*/

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../constants/constants.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  String _role = 'user';
  String? _sessionToken;

  // ── Getters ───────────────────────────────────────────────────────────────

  String get currentRole => _role;
  bool get isAdmin => _role == 'admin';
  bool get isStudio => _role == 'studio';

  /// True when the session holds any privileged role (admin OR studio).
  /// Useful for "can this session post via a session token" checks.
  bool get isPrivileged => _role == 'admin' || _role == 'studio';

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
      // The server tells us which password matched. Default to 'admin'
      // for backwards-compatibility with any old response that omits the
      // role field (pre-studio deploy).
      final returnedRole = body['role'] as String?;
      _role = returnedRole == 'studio' ? 'studio' : 'admin';
      _sessionToken = body['token'] as String?;
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
