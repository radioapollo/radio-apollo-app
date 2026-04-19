/* Chat Title Widget

   Displays the chat title, username, or admin mode badge.
   Also shows the logout button when in admin mode,
   or a "Kies een naam" button when the user has no username yet.

   This is a pure presentation widget — all state is passed in
   via constructor parameters.
*/

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class ChatTitle extends StatelessWidget {
  final bool isAdmin;
  final String? username;
  final bool hasUsername;
  final VoidCallback onLogout;
  final VoidCallback? onPickUsername;

  const ChatTitle({
    super.key,
    required this.isAdmin,
    required this.hasUsername,
    required this.onLogout,
    this.username,
    this.onPickUsername,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingXLarge,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Chat met de Studio',
                  style: AppTextStyles.chatTitle,
                ),
                if (isAdmin)
                  const Padding(
                    padding: EdgeInsets.only(top: AppDimensions.spaceSmall),
                    child: Text('ADMIN MODE', style: AppTextStyles.adminBadge),
                  )
                else if (hasUsername && username != null)
                  Padding(
                    padding: const EdgeInsets.only(
                      top: AppDimensions.spaceXSmall,
                    ),
                    child: Text(
                      'Ingelogd als: $username',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Logout button (admin only) ────────────────────────────────────
          if (isAdmin)
            TextButton.icon(
              onPressed: onLogout,
              icon: const Icon(
                Icons.logout,
                size: 18,
                color: AppColors.textSecondary,
              ),
              label: const Text(
                'Uitloggen',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            )
          // ── Pick username button (no username yet) ────────────────────────
          else if (!hasUsername && onPickUsername != null)
            TextButton.icon(
              onPressed: onPickUsername,
              icon: const Icon(
                Icons.person_add_alt_1,
                size: 18,
                color: AppColors.primaryLight,
              ),
              label: const Text(
                'Kies een naam',
                style: TextStyle(
                  color: AppColors.primaryLight,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
