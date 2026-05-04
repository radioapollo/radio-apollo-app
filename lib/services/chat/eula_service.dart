/* EULA Service

   Tracks whether the user has accepted the chat gebruiksvoorwaarden
   (Terms of Use). Acceptance is required before sending any chat
   message — Apple Guideline 1.2 requires a published EULA that
   prohibits objectionable content, and explicit user agreement.

   Stored in SharedPreferences as a boolean + version string. If we
   ever materially change the Terms, bump termsVersion and existing
   users will be re-prompted to accept the new version.
*/

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EulaService extends ChangeNotifier {
  EulaService._();
  static final EulaService instance = EulaService._();

  static const String currentVersion = '2026-05-02';

  static const _acceptedKey = 'chat_eula_accepted_version';

  String? _acceptedVersion;
  bool _initialised = false;

  bool get isInitialised => _initialised;

  bool get hasAccepted => _acceptedVersion == currentVersion;

  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;
    final prefs = await SharedPreferences.getInstance();
    _acceptedVersion = prefs.getString(_acceptedKey);
  }

  Future<void> accept() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_acceptedKey, currentVersion);
    _acceptedVersion = currentVersion;
    notifyListeners();
  }
}
