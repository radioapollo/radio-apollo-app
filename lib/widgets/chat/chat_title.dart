/* Chat Title Widget

   Displays the chat title, username, or admin mode badge.
   Also shows the logout button when in admin mode.
*/

import 'package:flutter/material.dart';
import '../../services/chat/auth_service.dart';
import '../../services/chat/user_service.dart';
import '../../theme/app_theme.dart';

class ChatTitle extends StatelessWidget {
  final AuthService authService;
  final VoidCallback onLogout;

  const ChatTitle({
    super.key,
    required this.authService,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final username = UserService.instance.username;

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingXLarge),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Chat met de Studio',
                    style: AppTextStyles.chatTitle),
                if (authService.isAdmin)
                  const Padding(
                    padding: EdgeInsets.only(top: AppDimensions.spaceSmall),
                    child: Text('ADMIN MODE',
                        style: AppTextStyles.adminBadge),
                  )
                else if (username != null)
                  Padding(
                    padding: const EdgeInsets.only(
                        top: AppDimensions.spaceXSmall),
                    child: Text(
                      'Ingelogd als: $username',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),

          // ── Logout button (admin only) ────────────────────────────────────
          if (authService.isAdmin)
            TextButton.icon(
              onPressed: onLogout,
              icon: const Icon(Icons.logout, size: 18, color: AppColors.textSecondary),
              label: const Text('Uitloggen',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ),
        ],
      ),
    );
  }
}