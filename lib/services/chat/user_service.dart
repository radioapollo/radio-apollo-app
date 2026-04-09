/* User Service

   Manages the local user identity across app restarts.

   It handles:
   - loading the saved username from device storage on startup
   - checking Firestore to ensure the username is unique
   - claiming the username in Firestore so nobody else can take it
   - saving the username locally on the device
*/

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserService {
  UserService._();

  static final UserService instance = UserService._();

  static const String _key = 'chat_username';
  final _db = FirebaseFirestore.instance;

  String? _username;

  // ── Getters ───────────────────────────────────────────────────────────────

  String? get username    => _username;
  bool    get hasUsername => _username != null && _username!.isNotEmpty;

  // ── Storage ───────────────────────────────────────────────────────────────

  /// Call once at app startup to load the previously saved username.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _username = prefs.getString(_key);

    // Re-claim if the username was cleaned up from Firestore
    if (_username != null && _username!.isNotEmpty) {
      final docId = _username!.toLowerCase();
      final doc = await _db.collection('usernames').doc(docId).get();
      if (!doc.exists) {
        await _db.collection('usernames').doc(docId).set({
          'displayName': _username!,
          'claimedAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }
  
  /// Claims and saves a new username. Throws if the name is taken.
  Future<void> setUsername(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    final docId = trimmed.toLowerCase();

    // Check if already taken
    final doc = await _db.collection('usernames').doc(docId).get();
    if (doc.exists) {
      throw Exception('Deze naam is al in gebruik. Kies een andere.');
    }

    // Claim the username in Firestore
    await _db.collection('usernames').doc(docId).set({
      'displayName': trimmed,
      'claimedAt': FieldValue.serverTimestamp(),
    });

    // Save locally
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, trimmed);
    _username = trimmed;
  }
}