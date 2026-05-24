/* Message Actions Sheet

   Long-press a chat message to open the action menu.

   Actions visible to everyone:
   - Kopiëren           → copies the message body to the system clipboard

   Admin-only actions (added when AuthService.instance.isAdmin):
   - Verwijder bericht  → calls AdminModerationService.deleteMessage
   - Verban [user]      → calls AdminModerationService.banUsername

   Station messages (admin "Radio Apollo" / studio "Studio") and the
   admin's own messages skip the admin sub-menu's BAN action — you
   can't meaningfully ban the station's own identities, and a username
   ban wouldn't affect the password-backed studio account anyway. An
   admin can still DELETE a station message (e.g. remove a studio post).
   Copy is always available on every message.

   For users (non-admin), MessageBubble registers a long-press handler
   that opens this sheet with just the "Kopiëren" entry.
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
    final isStationMessage =
        message.role == 'admin' || message.role == 'studio';
    final username = message.username;

    // Admins can delete any non-own message (including station posts).
    final canDelete = isAdmin && !isOwn;
    // Banning only makes sense for a real user's claimed name, not for
    // the station identities ("Radio Apollo" / "Studio").
    final canBan = isAdmin && !isOwn && !isStationMessage && username != null;

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

              // ── Admin: delete ─────────────────────────────────────────────
              if (canDelete)
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

              // ── Admin: ban (real users only) ──────────────────────────────
              if (canBan)
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
