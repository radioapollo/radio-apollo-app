/* Admin Moderation Service

   Client-side wrapper around the admin moderation Cloud Functions:
   - banUsername:   permanently blocks a username from chatting
   - unbanUsername: lifts a previous ban
   - deleteMessage: removes a single message from chat_messages

   All three require a valid admin session token; AuthService holds it.

   These calls intentionally use plain HTTP (not AppCheckHttp) because
   the admin endpoints validate the session token instead of App Check.
*/

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../constants/constants.dart';
import 'auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/report.dart';

class AdminModerationService {
  AdminModerationService._();
  static final AdminModerationService instance = AdminModerationService._();

  // ── Ban / unban ───────────────────────────────────────────────────────────

  Future<void> banUsername(String username, {String? reason}) async {
    await _post('adminBanUsername', {
      'username': username,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    });
  }

  Future<void> unbanUsername(String username) async {
    await _post('adminUnbanUsername', {'username': username});
  }

  // ── Delete a message ──────────────────────────────────────────────────────

  Future<void> deleteMessage(String messageId) async {
    await _post('adminDeleteMessage', {'messageId': messageId});
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  Future<void> _post(String name, Map<String, dynamic> payload) async {
    final token = AuthService.instance.sessionToken;
    if (token == null) {
      throw Exception('Niet ingelogd als admin.');
    }

    final uri = Uri.parse(AppConstants.cloudFunctionUrl(name));
    final body = {'token': token, ...payload};

    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 401) {
      throw Exception('Sessie verlopen. Log opnieuw in.');
    }
    if (response.statusCode != 200) {
      String message = 'Actie mislukt. Probeer opnieuw.';
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['error'] is String) {
          message = decoded['error'] as String;
        }
      } catch (_) {}
      throw Exception(message);
    }
  }

  // ── Reports ───────────────────────────────────────────────────────────────

  Stream<List<Report>> pendingReportsStream() {
    return FirebaseFirestore.instance
        .collection('chat_reports')
        .where('status', isEqualTo: 'pending')
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) => snap.docs.map(Report.fromDoc).toList());
  }

  Future<void> updateReport({
    required String reportId,
    required String status,
    String? action,
  }) async {
    await _post('adminUpdateReport', {
      'reportId': reportId,
      'status': status,
      'action': ?action,
    });
  }
}
