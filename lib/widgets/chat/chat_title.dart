/* Chat Title Widget

   Displays the chat title, username, or mode badge.

   Modes:
   - admin  → "ADMIN MODE" (orange) + logout + reports inbox button
   - studio → "STUDIO MODE" (green) + logout
   - user   → "Ingelogd als: <name>" or a "Kies een naam" button

   This is a pure presentation widget — all state is passed in
   via constructor parameters.
*/

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';

class ChatTitle extends StatelessWidget {
  final bool isAdmin;
  final bool isStudio;
  final String? username;
  final bool hasUsername;
  final VoidCallback onLogout;
  final VoidCallback? onPickUsername;
  final VoidCallback? onOpenReports;

  const ChatTitle({
    super.key,
    required this.isAdmin,
    required this.hasUsername,
    required this.onLogout,
    this.isStudio = false,
    this.username,
    this.onPickUsername,
    this.onOpenReports,
  });

  bool get _isPrivileged => isAdmin || isStudio;

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
                Text('Chat met de Studio', style: AppTextStyles.chatTitle),
                if (isAdmin)
                  const Padding(
                    padding: EdgeInsets.only(top: AppDimensions.spaceSmall),
                    child: Text('ADMIN MODE', style: AppTextStyles.adminBadge),
                  )
                else if (isStudio)
                  const Padding(
                    padding: EdgeInsets.only(top: AppDimensions.spaceSmall),
                    child: Text(
                      'STUDIO MODE',
                      style: TextStyle(
                        color: AppColors.studioBadge,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else if (hasUsername && username != null)
                  Padding(
                    padding: const EdgeInsets.only(
                      top: AppDimensions.spaceXSmall,
                    ),
                    child: Text(
                      'Ingelogd als: $username',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Reports button (admin only, with badge) ───────────────────────
          if (isAdmin && onOpenReports != null)
            _ReportsButton(onTap: onOpenReports!),

          // ── Logout button (admin or studio) ───────────────────────────────
          if (_isPrivileged)
            TextButton.icon(
              onPressed: onLogout,
              icon: Icon(
                Icons.logout,
                size: 18,
                color: AppColors.textSecondary,
              ),
              label: Text(
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

class _ReportsButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ReportsButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chat_reports')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snap) {
        final count = snap.data?.docs.length ?? 0;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: Icon(Icons.flag_outlined, color: AppColors.textPrimary),
              onPressed: onTap,
              tooltip: 'Meldingen',
            ),
            if (count > 0)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.live,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
