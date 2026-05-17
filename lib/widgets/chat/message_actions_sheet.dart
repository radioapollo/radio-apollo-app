/* Message Actions Sheet

   Long-press a chat message to open the action menu.

   Actions visible to everyone:
   - Kopiëren           → copies the message body to the system clipboard

   Admin-only actions (added when AuthService.instance.isAdmin):
   - Verwijder bericht  → calls AdminModerationService.deleteMessage
   - Verban [user]      → calls AdminModerationService.banUsername

   Own messages and admin messages skip the admin sub-menu, since
   you can't moderate yourself or the studio role. Copy is still
   available on every message regardless of who sent it.

   For users (non-admin), MessageBubble registers a long-press handler
   that opens this sheet with just the "Kopiëren" entry. The icon-
   button row under each bubble (like / reply / flag) is unchanged —
   long-press is purely an additional discovery path for copying text.
*/

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/message.dart';
import '../../services/chat/auth_service.dart';
import '../../services/chat/admin_moderation_service.dart';
import '../../theme/app_theme.dart';

class MessageActionsSheet {
  static Future<void> show(BuildContext context, Message message) async {
    final isAdmin = AuthService.instance.isAdmin;
    final isOwn = message.isCurrentUser;
    final isAdminMessage = message.role == 'admin';
    final username = message.username;
    final canModerate = isAdmin && !isOwn && !isAdminMessage;

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
              // ── Kopiëren (everyone) ───────────────────────────────────────
              ListTile(
                leading: const Icon(
                  Icons.content_copy_outlined,
                  color: AppColors.primaryLight,
                ),
                title: const Text('Kopiëren'),
                subtitle: const Text('Kopieer dit bericht naar het klembord.'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _copyToClipboard(context, message.text);
                },
              ),

              // ── Admin actions (only when canModerate) ─────────────────────
              if (canModerate) ...[
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline,
                    color: AppColors.offlineIcon,
                  ),
                  title: const Text('Verwijder bericht'),
                  subtitle: const Text('Het bericht verdwijnt voor iedereen.'),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _confirmDeleteMessage(context, message);
                  },
                ),
                if (username != null)
                  ListTile(
                    leading: const Icon(
                      Icons.gavel_outlined,
                      color: AppColors.offlineIcon,
                    ),
                    title: Text('Verban $username'),
                    subtitle: const Text(
                      'Deze gebruikersnaam kan nooit meer chatten.',
                    ),
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      await _confirmBanUsername(context, username);
                    },
                  ),
              ],

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

  // ── Copy ────────────────────────────────────────────────────────────────

  static Future<void> _copyToClipboard(
    BuildContext context,
    String text,
  ) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    // Android 13+ shows its own "copied to clipboard" toast, so showing
    // a SnackBar would be redundant on new devices. Older Androids and
    // iOS don't, so we always show one — duplicate feedback is better
    // than silent feedback.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bericht gekopieerd.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // ── Admin: confirm + delete ──────────────────────────────────────────────

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

  // ── Admin: confirm + ban ─────────────────────────────────────────────────

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
            const SizedBox(height: AppDimensions.spaceMedium),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reden (optioneel)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
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
            child: const Text('Verban'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

    final reason = reasonController.text.trim();
    try {
      await AdminModerationService.instance.banUsername(
        username,
        reason: reason.isEmpty ? null : reason,
      );
      if (!context.mounted) return;
      _snack(context, '$username is verbannen.');
    } catch (e) {
      if (!context.mounted) return;
      _snack(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // ── Snackbar helper ─────────────────────────────────────────────────────

  static void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }
}
