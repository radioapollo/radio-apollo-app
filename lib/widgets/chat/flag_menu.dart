/* Flag Menu

   Shown when a user taps the flag (🚩) icon under a chat message.
   Offers two options:

   - Blokkeer [username]    → adds the username to BlockService so the
                              user no longer sees their messages
   - Rapporteer bericht     → continues to the existing report reason
                              picker via MessageReportFlow

   This used to live behind a long-press menu, but we moved it to a
   dedicated flag button so the actions are discoverable. The flag
   button isn't shown on admin messages, so blocking-the-studio is
   not reachable here.
*/

import 'package:flutter/material.dart';
import '../../models/message.dart';
import '../../services/chat/block_service.dart';
import '../../theme/app_theme.dart';
import 'message_report_flow.dart';

class FlagMenu {
  FlagMenu._();

  static Future<void> show(BuildContext context, Message message) async {
    final username = message.username;

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
              if (username != null)
                ListTile(
                  leading: const Icon(
                    Icons.block,
                    color: AppColors.offlineIcon,
                  ),
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
              ListTile(
                leading: const Icon(
                  Icons.flag_outlined,
                  color: AppColors.offlineIcon,
                ),
                title: const Text('Rapporteer bericht'),
                subtitle: const Text(
                  'We bekijken elk gerapporteerd bericht binnen 24 uur.',
                ),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  if (!context.mounted) return;
                  await MessageReportFlow.start(context, message);
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
}
