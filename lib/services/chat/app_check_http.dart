/* Cloud Function HTTP helper

   Wraps a POST to a Cloud Function URL with an optional App Check token.
   Used by ChatService (userSendMessage) and UserService (claimUsername)
   so both share the same timeout, error handling, and token-fetching
   strategy.

   App Check is best-effort by default: if the token call fails or times
   out, we still send the request without it. The server decides whether
   to enforce strictly or soft-fail. Pass `requireAppCheck: true` to
   surface a meaningful error instead of falling back silently.
*/

import 'dart:async';
import 'dart:convert';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:http/http.dart' as http;
import '../../constants/constants.dart';

class AppCheckHttp {
  static const Duration _appCheckTimeout = Duration(seconds: 5);
  static const Duration _httpTimeout = Duration(seconds: 15);

  /// POSTs `body` (as JSON) to the named Cloud Function and returns the
  /// raw response. Throws on network failure or HTTP timeout, but never
  /// on App Check failure unless `requireAppCheck` is true.
  static Future<http.Response> post(
    String functionName,
    Map<String, dynamic> body, {
    bool requireAppCheck = false,
  }) async {
    final token = await _tryGetAppCheckToken(throwOnFailure: requireAppCheck);

    final uri = Uri.parse(AppConstants.cloudFunctionUrl(functionName));

    try {
      return await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'X-Firebase-AppCheck': token,
            },
            body: jsonEncode(body),
          )
          .timeout(_httpTimeout);
    } on TimeoutException {
      throw Exception('Server antwoordt niet. Probeer het later opnieuw.');
    } catch (_) {
      throw Exception(
        'Bericht kon niet worden verzonden. Controleer je netwerk.',
      );
    }
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  static Future<String?> _tryGetAppCheckToken({
    required bool throwOnFailure,
  }) async {
    try {
      return await FirebaseAppCheck.instance.getToken().timeout(
        _appCheckTimeout,
      );
    } catch (_) {
      if (throwOnFailure) {
        throw Exception('Kon geen beveiligingstoken ophalen. Probeer opnieuw.');
      }
      return null;
    }
  }
}