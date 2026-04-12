/* Now Playing Program Card Widget

   This widget displays the currently airing radio program
   on the home screen, directly below the live player card.

   It shows:
   - the program image (or a fallback radio icon)
   - the program title
   - the presenter name
   - the time slot
   - a small "Nu bezig" indicator

   It listens to CurrentProgramService for data — all Firestore
   fetching, time logic, and caching live in that service.
*/

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'service_provider.dart';
import '../services/program/current_program_service.dart';
import '../theme/app_theme.dart';

class NowPlayingProgramCard extends StatelessWidget {
  final VoidCallback? onTap;

  const NowPlayingProgramCard({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cpService = ServiceProvider.of(context).currentProgramService;

    return StreamBuilder<CurrentProgram>(
      stream: cpService.currentProgram,
      initialData: cpService.lastProgram,
      builder: (context, snapshot) {
        final program = snapshot.data;
        if (program == null || !program.hasData) {
          return const SizedBox.shrink();
        }

        return GestureDetector(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.paddingXLarge,
              vertical: AppDimensions.paddingMedium,
            ),
            decoration: BoxDecoration(
              color: AppColors.navyMedium,
              borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
              border: Border.all(
                color: AppColors.borderSubtle,
                width: AppDimensions.borderThin,
              ),
            ),
            child: Row(
              children: [
                _buildImage(program.imageUrl),
                const SizedBox(width: AppDimensions.spaceLarge),
                Expanded(child: _buildInfo(program)),
                if (onTap != null)
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.loadingIndicator,
                    size: AppDimensions.iconLarge,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Image ─────────────────────────────────────────────────────────────────

  Widget _buildImage(String? imageUrl) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
      child: imageUrl != null && imageUrl.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: imageUrl,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => _buildFallbackIcon(),
            )
          : _buildFallbackIcon(),
    );
  }

  Widget _buildFallbackIcon() {
    return Container(
      width: 48,
      height: 48,
      decoration: const BoxDecoration(color: AppColors.borderSubtle),
      child: const Icon(
        Icons.radio,
        color: AppColors.iconOnDarkMuted,
        size: AppDimensions.iconLarge,
      ),
    );
  }

  // ── Info column ───────────────────────────────────────────────────────────

  Widget _buildInfo(CurrentProgram program) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // "Nu bezig" label + time
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.nuBezigBadgePaddingH,
                vertical: AppDimensions.nuBezigBadgePaddingV,
              ),
              decoration: AppDecorations.nuBezigBadge(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.circle,
                    size: AppDimensions.nuBezigIconSize,
                    color: AppColors.nowPlayingDot,
                  ),
                  const SizedBox(width: AppDimensions.nuBezigIconSpacing),
                  const Text('Nu bezig', style: AppTextStyles.nuBezigLabel),
                ],
              ),
            ),
            const SizedBox(width: AppDimensions.spaceSmall),
            if (program.timeSlot != null)
              Text(program.timeSlot!, style: AppTextStyles.darkCardTime),
          ],
        ),
        const SizedBox(height: AppDimensions.spaceSmall),
        // Program title
        Text(
          program.title!,
          style: AppTextStyles.darkCardTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        // Presenter
        if (program.presenter != null && program.presenter!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppDimensions.spaceXSmall),
            child: Text(
              program.presenter!,
              style: AppTextStyles.darkCardSubtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }
}