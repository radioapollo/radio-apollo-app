/* User Service

   Manages the local user identity across app restarts.

   It handles:
   - loading the saved username from device storage on startup
   - saving a new username chosen in the dialog
   - exposing whether a username has been set yet
*/

import 'package:shared_preferences/shared_preferences.dart';

class UserService {
  UserService._();

  static final UserService instance = UserService._();

  static const String _key = 'chat_username';

  String? _username;

  // ── Getters ───────────────────────────────────────────────────────────────

  String? get username    => _username;
  bool    get hasUsername => _username != null && _username!.isNotEmpty;

  // ── Storage ───────────────────────────────────────────────────────────────

  /// Call once at app startup to load the previously saved username.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _username = prefs.getString(_key);
  }

  /// Saves a new username to the device and memory.
  Future<void> setUsername(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, trimmed);
    _username = trimmed;
  }
}