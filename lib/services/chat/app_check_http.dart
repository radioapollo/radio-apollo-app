/* Cloud Function HTTP helper

   Wraps a POST to a Cloud Function URL with an optional App Check token.
   Used by ChatService (userSendMessage) and UserService (claimUsername)
   so both share the same timeout, error handling, and token-fetching
   strategy.

   App Check is best-effort by default: if the token call fails or times
   out, we still send the request without it. The server decides whether
   to enforce strictly or soft-fail. Pass `requireAppCheck: true` to
   surface a meaningful error instead of falling back silently.

   ─── Testability ───────────────────────────────────────────────────────────
   The underlying http.Client and the App Check token fetcher are both
   injectable. Production callers omit the parameters and get the real
   http.Client and FirebaseAppCheck.instance.getToken. Tests can pass a
   MockClient and a stub token fetcher to exercise all branches without
   any network or Firebase setup.
*/

import 'dart:async';
import 'dart:convert';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:http/http.dart' as http;
import '../../constants/constants.dart';

/// Signature for the App Check token fetcher. Returning null is treated
/// the same as throwing — no token is attached. Throwing is reserved for
/// "token fetch failed and the caller insisted on having one".
typedef AppCheckTokenFetcher =
    Future<String?> Function({required Duration timeout});

class AppCheckHttp {
  static const Duration _appCheckTimeout = Duration(seconds: 5);
  static const Duration _httpTimeout = Duration(seconds: 15);

  /// Override the http.Client in tests. Defaults to a fresh http.Client.
  static http.Client Function() clientFactory = http.Client.new;

  /// Override the App Check token fetcher in tests. Defaults to the
  /// real FirebaseAppCheck.instance.getToken.
  static AppCheckTokenFetcher tokenFetcher = _defaultTokenFetcher;

  /// Resets the static overrides back to production defaults. Tests
  /// should call this in tearDown so leaked overrides can't poison
  /// other suites.
  static void resetForTesting() {
    clientFactory = http.Client.new;
    tokenFetcher = _defaultTokenFetcher;
  }

  static Future<String?> _defaultTokenFetcher({
    required Duration timeout,
  }) async {
    return FirebaseAppCheck.instance.getToken().timeout(timeout);
  }

  static Future<http.Response> post(
    String functionName,
    Map<String, dynamic> body, {
    bool requireAppCheck = false,
  }) async {
    final token = await _tryGetAppCheckToken(throwOnFailure: requireAppCheck);

    final uri = Uri.parse(AppConstants.cloudFunctionUrl(functionName));
    final client = clientFactory();

    try {
      return await client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'X-Firebase-AppCheck': ?token,
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
    } finally {
      client.close();
    }
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  static Future<String?> _tryGetAppCheckToken({
    required bool throwOnFailure,
  }) async {
    try {
      return await tokenFetcher(timeout: _appCheckTimeout);
    } catch (_) {
      if (throwOnFailure) {
        throw Exception('Kon geen beveiligingstoken ophalen. Probeer opnieuw.');
      }
      return null;
    }
  }
}
