/* Message Report Flow

   Extracted out of MessageActionsSheet so both the long-press admin
   menu and the new per-message flag button can trigger the same
   report flow without duplicating the reason picker UI.

   Calls into ReportService to write the report doc to Firestore,
   then shows a thank-you / failure snackbar.
*/

import 'package:flutter/material.dart';
import '../../models/message.dart';
import '../../theme/app_theme.dart';
import 'report_service.dart';

class MessageReportFlow {
  MessageReportFlow._();

  static const _reasons = <String>[
    'Spam of misleidend',
    'Pesten of intimidatie',
    'Haatspraak',
    'Ongepaste of seksuele inhoud',
    'Geweld of bedreiging',
    'Andere reden',
  ];

  /// Opens the reason picker, then writes the report and shows a
  /// snackbar with the result. Safe to call on any non-own message.
  static Future<void> start(BuildContext context, Message message) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.scaffoldBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Waarom rapporteer je dit bericht?',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
              ),
              for (final r in _reasons)
                ListTile(
                  title: Text(r),
                  onTap: () => Navigator.pop(sheetContext, r),
                ),
            ],
          ),
        );
      },
    );

    if (selected == null) return;
    if (!context.mounted) return;

    final ok = await ReportService.instance.report(
      messageId: message.id,
      reportedUsername: message.username,
      reportedText: message.text,
      reason: selected,
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Bedankt — we bekijken je melding binnen 24 uur.'
              : 'Melden lukte niet. Probeer het later opnieuw.',
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
