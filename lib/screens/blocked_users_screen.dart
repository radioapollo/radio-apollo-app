/* Blocked Users Screen

   Lists every username the current user has personally blocked,
   with a one-tap unblock action.

   This is the user-facing counterpart to the long-press "Blokkeer"
   action on chat messages. Apple Guideline 1.2 requires that any
   block users perform must be reversible — this screen is how.

   Block list lives in BlockService (SharedPreferences). Updates
   are immediate: unblocking removes the name from the list and
   the user's chat will show their messages again on the next
   stream emission.
*/

import 'package:flutter/material.dart';
import '../services/chat/block_service.dart';
import '../theme/app_theme.dart';

class BlockedUsersScreen extends StatelessWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SizedBox.expand(
        child: Container(
          decoration: const BoxDecoration(
            image: AppDecorations.backgroundWatermark,
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                Expanded(
                  child: AnimatedBuilder(
                    animation: BlockService.instance,
                    builder: (context, _) {
                      final blocked =
                          BlockService.instance.blocked.toList()..sort();
                      if (blocked.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Je hebt niemand geblokkeerd.',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          AppDimensions.paddingXLarge,
                          0,
                          AppDimensions.paddingXLarge,
                          AppDimensions.paddingXLarge,
                        ),
                        itemCount: blocked.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: AppDimensions.spaceSmall),
                        itemBuilder: (context, i) =>
                            _BlockedRow(username: blocked[i]),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.paddingXLarge,
        AppDimensions.paddingXLarge,
        AppDimensions.paddingXLarge,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: AppColors.textPrimary,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spaceMedium),
          const Text(
            'Geblokkeerde gebruikers',
            style: AppTextStyles.screenTitle,
          ),
          const SizedBox(height: AppDimensions.spaceLarge),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// _BlockedRow
// ════════════════════════════════════════════════════════════════════════════

class _BlockedRow extends StatelessWidget {
  final String username;
  const _BlockedRow({required this.username});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingMedium,
        vertical: AppDimensions.paddingSmall,
      ),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.person_off_outlined,
            color: AppColors.textSecondary,
            size: 20,
          ),
          const SizedBox(width: AppDimensions.spaceMedium),
          Expanded(
            child: Text(
              username,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => _confirmUnblock(context),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryLight,
            ),
            child: const Text(
              'Deblokkeer',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmUnblock(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$username deblokkeren?'),
        content: Text(
          'Je ziet weer alle berichten van $username in de chat.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuleren'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Deblokkeer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

    await BlockService.instance.unblock(username);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$username is gedeblokkeerd.'),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}