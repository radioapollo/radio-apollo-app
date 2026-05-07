/* Message Actions Sheet

   Long-press a chat message to open the admin moderation menu.

   Per-user actions (like / reply / report / block) used to live here
   too, behind the same long-press. They've moved to visible icon
   buttons under each message bubble — see MessageBubble. This sheet
   is now ADMIN-ONLY: regular users never see it.

   Admin actions:
   - Verwijder bericht  → calls AdminModerationService.deleteMessage
   - Verban [user]      → calls AdminModerationService.banUsername

   For users (non-admin), MessageBubble does NOT register a long-press
   handler at all, so this sheet is unreachable to them.
*/

import 'package:flutter/material.dart';
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

    if (!isAdmin) return;
    if (isOwn) return;
    if (isAdminMessage) return;

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
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(labelText: 'Reden (optioneel)'),
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

  // ── Helpers ──────────────────────────────────────────────────────────────

  static void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 4)),
    );
  }
}
