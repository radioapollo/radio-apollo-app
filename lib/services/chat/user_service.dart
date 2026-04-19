/* User Service

   Manages the local user identity across app restarts.

   It handles:
   - loading the saved username from device storage on startup
   - checking Firestore to ensure the username is unique
   - claiming the username in Firestore atomically (transaction)
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

  String? get username => _username;
  bool get hasUsername => _username != null && _username!.isNotEmpty;

  // ── Storage ───────────────────────────────────────────────────────────────

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _username = prefs.getString(_key);

    if (_username != null && _username!.isNotEmpty) {
      final docId = _username!.toLowerCase();
      final doc = await _db.collection('usernames').doc(docId).get();
      if (!doc.exists) {
        try {
          await _db.collection('usernames').doc(docId).set({
            'displayName': _username!,
            'claimedAt': FieldValue.serverTimestamp(),
          });
        } catch (_) {
          _username = null;
          await prefs.remove(_key);
        }
      }
    }
  }

  Future<void> setUsername(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    final docId = trimmed.toLowerCase();
    final docRef = _db.collection('usernames').doc(docId);

    final existing = await docRef.get();
    if (existing.exists) {
      throw Exception('Deze naam is al in gebruik. Kies een andere.');
    }

    try {
      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);

        if (snapshot.exists) {
          throw Exception('Deze naam is al in gebruik. Kies een andere.');
        }

        transaction.set(docRef, {
          'displayName': trimmed,
          'claimedAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      if (e is Exception && e.toString().contains('al in gebruik')) {
        rethrow;
      }
      throw Exception('Deze naam is al in gebruik. Kies een andere.');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, trimmed);
    _username = trimmed;
  }
}
