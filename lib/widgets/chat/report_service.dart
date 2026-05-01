/* Report Service

   Writes user-submitted message reports to Firestore so the
   studio admin can review and act on them within 24 hours.

   Why a direct Firestore write?
   ─────────────────────────────
   - Reports go into the dedicated `chat_reports` collection.
   - Firestore security rules restrict creates to the shape we
     allow here (no admin reads from clients).
   - A future iteration can move this behind a Cloud Function
     for IP-based rate limiting and message-existence checks.
*/

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../services/chat/user_service.dart';

class ReportService {
  ReportService._();
  static final ReportService instance = ReportService._();

  static const _collection = 'chat_reports';

  /// Returns true on success, false on any failure. Never throws.
  Future<bool> report({
    required String? messageId,
    required String? reportedUsername,
    required String reportedText,
    required String reason,
  }) async {
    try {
      await FirebaseFirestore.instance.collection(_collection).add({
        'messageId': messageId,
        'reportedUsername': reportedUsername,
        'reportedText': reportedText,
        'reason': reason,
        'reporterUsername': UserService.instance.username,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
      return true;
    } catch (e, st) {
      debugPrint('[ReportService] report failed: $e\n$st');
      return false;
    }
  }
}