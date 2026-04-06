/* User Service

   This service manages the local user identity.

   It handles:
   - storing a chosen username on the device (persists across app restarts)
   - retrieving the username on startup
   - checking whether a username has been set yet

   Uses shared_preferences so the username is saved locally, no account needed.
*/

import 'package:shared_preferences/shared_preferences.dart';

class UserService {
  UserService._();

  static final UserService instance = UserService._();

  static const String _key = 'chat_username';

  String? _username;

  String? get username => _username;

  bool get hasUsername => _username != null && _username!.isNotEmpty;

  /// Call this once at app startup to load the saved username.
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

  /// Clears the stored username (useful for testing).
  Future<void> clearUsername() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    _username = null;
  }
}