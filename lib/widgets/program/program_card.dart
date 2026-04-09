/* Program Card Widget

   This widget displays a single radio program in the schedule.

   It shows:
   - the program image (from network) or a fallback radio icon
   - the broadcast time
   - the program title
   - a short description
   - a "Nu bezig" badge if the program is currently playing
*/

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class ProgramCard extends StatelessWidget {
  final String time;
  final String title;
  final String subtitle;
  final String imageUrl;
  final Border? border;
  final bool isCurrent;

  const ProgramCard({
    super.key,
    required this.time,
    required this.title,
    required this.subtitle,
    this.imageUrl = '',
    this.border,
    this.isCurrent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.paddingLarge),
      padding: const EdgeInsets.all(AppDimensions.paddingXLarge),
      decoration: isCurrent
          ? AppDecorations.currentProgramCard()
          : AppDecorations.darkCard(radius: AppDimensions.radiusXLarge),
      child: Row(
        children: [
          _buildImage(),
          const SizedBox(width: AppDimensions.paddingLarge),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isCurrent) _buildNuBezigBadge(),
                Text(time, style: AppTextStyles.darkCardTime),
                const SizedBox(height: AppDimensions.spaceXSmall),
                Text(title, style: AppTextStyles.darkCardTitle),
                const SizedBox(height: AppDimensions.spaceXSmall),
                if (subtitle.isNotEmpty)
                  Text(subtitle, style: AppTextStyles.darkCardSubtitle),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage() {
    const double size = 48;
    const borderRadius = BorderRadius.all(
        Radius.circular(AppDimensions.radiusSmall + 2));

    if (imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: Image.network(
          imageUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: size,
              height: size,
              decoration: AppDecorations.programIconBg,
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white38,
                  ),
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) => _buildFallbackIcon(),
        ),
      );
    }

    return _buildFallbackIcon();
  }

  Widget _buildFallbackIcon() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingSmall),
      decoration: AppDecorations.programIconBg,
      child: const Icon(Icons.radio,
          color: Colors.white, size: AppDimensions.iconXLarge),
    );
  }

  Widget _buildNuBezigBadge() {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.spaceSmall),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.nuBezigBadgePaddingH,
        vertical: AppDimensions.nuBezigBadgePaddingV,
      ),
      decoration: AppDecorations.nuBezigBadge(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.circle,
              color: Colors.redAccent,
              size: AppDimensions.nuBezigIconSize),
          const SizedBox(width: AppDimensions.nuBezigIconSpacing),
          Text('NU BEZIG', style: AppTextStyles.nuBezigLabel),
        ],
      ),
    );
  }
}