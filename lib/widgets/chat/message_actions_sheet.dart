/* Message Actions Sheet

   Shown when the user long-presses a chat message bubble.

   Offers:
   - "Blokkeer [username]" → adds the username to BlockService
   - "Rapporteer bericht"  → opens a small reason picker, then
                              writes a report to Firestore via
                              ReportService.

   Hidden options:
   - Own messages: nothing to do, the sheet doesn't open.
   - Admin messages: blocking the studio is not allowed; only
                     the report option is shown (mostly for symmetry
                     and edge cases — admin never breaks the rules).
*/

import 'package:flutter/material.dart';
import 'package:radio_apollo/widgets/chat/report_service.dart';
import '../../models/message.dart';
import '../../services/chat/auth_service.dart';
import '../../services/chat/admin_moderation_service.dart';
import '../../services/chat/block_service.dart';
import '../../theme/app_theme.dart';

class MessageActionsSheet {
  static Future<void> show(BuildContext context, Message message) async {
    final isAdmin = AuthService.instance.isAdmin;
    final isOwn = message.isCurrentUser;
    final isAdminMessage = message.role == 'admin';
    final username = message.username;

    // Nothing to do on own messages, and admins can't moderate other admins.
    if (isOwn) return;
    if (isAdminMessage && !isAdmin) {
      // Regular users can still report admin messages in theory,
      // but in practice you might prefer not to. Up to you — we keep it.
    }

    await showModalBottomSheet<void>(
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
              // ── Admin-only actions ──────────────────────────────────────
              if (isAdmin && !isAdminMessage) ...[
                ListTile(
                  leading: const Icon(Icons.delete_outline,
                      color: AppColors.offlineIcon),
                  title: const Text('Verwijder bericht'),
                  subtitle: const Text(
                    'Het bericht verdwijnt voor iedereen.',
                  ),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _confirmDeleteMessage(context, message);
                  },
                ),
                if (username != null)
                  ListTile(
                    leading: const Icon(Icons.gavel_outlined,
                        color: AppColors.offlineIcon),
                    title: Text('Verban $username'),
                    subtitle: const Text(
                      'Deze gebruikersnaam kan nooit meer chatten.',
                    ),
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      await _confirmBanUsername(context, username);
                    },
                  ),
                const Divider(height: 1),
              ],

              // ── Per-user block (everyone, including admin) ──────────────
              if (!isAdminMessage && username != null)
                ListTile(
                  leading: const Icon(Icons.block,
                      color: AppColors.offlineIcon),
                  title: Text('Blokkeer $username'),
                  subtitle: const Text(
                    'Je ziet geen berichten meer van deze gebruiker.',
                  ),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await BlockService.instance.block(username);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$username is geblokkeerd.'),
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  },
                ),

              // ── Report (any non-own message) ────────────────────────────
              ListTile(
                leading: const Icon(Icons.flag_outlined,
                    color: AppColors.offlineIcon),
                title: const Text('Rapporteer bericht'),
                subtitle: const Text(
                  'We bekijken elk gerapporteerd bericht binnen 24 uur.',
                ),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _pickReasonAndReport(context, message);
                },
              ),

              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Annuleren'),
                onTap: () => Navigator.pop(sheetContext),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Admin: confirm + delete ─────────────────────────────────────────────────

  static Future<void> _confirmDeleteMessage(
    BuildContext context,
    Message message,
  ) async {
    if (message.id == null) {
      _snack(context, 'Dit bericht kan niet verwijderd worden.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bericht verwijderen?'),
        content: Text(
          '"${message.text}"\n\nVan ${message.username ?? "onbekend"}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuleren'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Verwijderen'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

    try {
      await AdminModerationService.instance.deleteMessage(message.id!);
      if (!context.mounted) return;
      _snack(context, 'Bericht verwijderd.');
    } catch (e) {
      if (!context.mounted) return;
      _snack(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // ── Admin: confirm + ban ───────────────────────────────────────────────────

  static Future<void> _confirmBanUsername(
    BuildContext context,
    String username,
  ) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$username verbannen?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Deze gebruikersnaam kan nooit meer chatten en kan niet '
              'opnieuw geclaimd worden.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reden (optioneel)',
              ),
              maxLength: 200,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuleren'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Verbannen'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

    try {
      await AdminModerationService.instance.banUsername(
        username,
        reason: reasonController.text.trim(),
      );
      if (!context.mounted) return;
      _snack(context, '$username is verbannen.');
    } catch (e) {
      if (!context.mounted) return;
      _snack(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // ── Existing report flow (unchanged) ───────────────────────────────────────

  static Future<void> _pickReasonAndReport(
    BuildContext context,
    Message message,
  ) async {
    const reasons = <String>[
      'Spam of misleidend',
      'Pesten of intimidatie',
      'Haatspraak',
      'Ongepaste of seksuele inhoud',
      'Geweld of bedreiging',
      'Andere reden',
    ];

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
              for (final r in reasons)
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
    _snack(
      context,
      ok
          ? 'Bedankt — we bekijken je melding binnen 24 uur.'
          : 'Melden lukte niet. Probeer het later opnieuw.',
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 4),
      ),
    );
  }
}