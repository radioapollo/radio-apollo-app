/* User Service

   Manages the local user identity across app restarts.

   It handles:
   - loading the saved username from device storage on startup
   - checking Firestore to ensure the username is unique
   - claiming the username in Firestore atomically (transaction)
   - saving the username locally on the device
*/

import 'dart:convert';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:http/http.dart' as http;
import '../../constants/constants.dart';
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
    final saved = prefs.getString(_key);
    if (saved == null || saved.isEmpty) return;
  
    try {
      final doc = await _db.collection('usernames').doc(saved.toLowerCase()).get();
      if (doc.exists) {
        _username = saved;
      } else {
        await prefs.remove(_key);
      }
    } catch (_) {
      // Network error — keep local value, best-effort.
      _username = saved;
    }
  }

  Future<void> setUsername(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
  
    String? appCheckToken;
    try {
      appCheckToken = await FirebaseAppCheck.instance.getToken();
    } catch (_) {
      throw Exception('Kon geen beveiligingstoken ophalen. Probeer opnieuw.');
    }
  
    final uri = Uri.parse(AppConstants.cloudFunctionUrl('claimUsername'));
  
    final response = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            if (appCheckToken != null) 'X-Firebase-AppCheck': appCheckToken,
          },
          body: jsonEncode({'name': trimmed}),
        )
        .timeout(const Duration(seconds: 15));
  
    if (response.statusCode == 409) {
      throw Exception('Deze naam is al in gebruik. Kies een andere.');
    }
    if (response.statusCode == 400) {
      String msg = 'Ongeldige naam.';
      try {
        final body = jsonDecode(response.body);
        if (body is Map && body['error'] is String) msg = body['error'];
      } catch (_) {}
      throw Exception(msg);
    }
    if (response.statusCode != 200) {
      throw Exception('Naam kon niet worden opgeslagen. Probeer opnieuw.');
    }
  
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, trimmed);
    _username = trimmed;
  }
}
