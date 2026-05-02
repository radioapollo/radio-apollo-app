/* Chat Report Model

   Represents a single user-submitted report against a chat message.

   Status values:
   - pending   → awaiting admin review
   - resolved  → admin acted (message deleted, user banned, etc.)
   - dismissed → admin reviewed and decided no action needed
*/

import 'package:cloud_firestore/cloud_firestore.dart';

class Report {
  final String id;
  final String? messageId;
  final String? reportedUsername;
  final String reportedText;
  final String reason;
  final String? reporterUsername;
  final DateTime? timestamp;
  final String status;
  final String? action;
  final DateTime? resolvedAt;

  const Report({
    required this.id,
    required this.reportedText,
    required this.reason,
    required this.status,
    this.messageId,
    this.reportedUsername,
    this.reporterUsername,
    this.timestamp,
    this.action,
    this.resolvedAt,
  });

  factory Report.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Report(
      id: doc.id,
      messageId: data['messageId'] as String?,
      reportedUsername: data['reportedUsername'] as String?,
      reportedText: data['reportedText'] as String? ?? '',
      reason: data['reason'] as String? ?? '',
      reporterUsername: data['reporterUsername'] as String?,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate(),
      status: data['status'] as String? ?? 'pending',
      action: data['action'] as String?,
      resolvedAt: (data['resolvedAt'] as Timestamp?)?.toDate(),
    );
  }
}