/* Program Card Widget

   This widget displays a single radio program in the schedule.

   It shows:
   - the broadcast time
   - the program title
   - a short description
   - a "Nu bezig" badge if the program is currently playing
*/

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ProgramCard extends StatelessWidget {
  final String time;
  final String title;
  final String subtitle;
  final Border? border;
  final bool isCurrent;

  const ProgramCard({
    super.key,
    required this.time,
    required this.title,
    required this.subtitle,
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
          Container(
            padding: const EdgeInsets.all(AppDimensions.paddingSmall),
            decoration: AppDecorations.programIconBg,
            child: const Icon(Icons.radio,
                color: Colors.white, size: AppDimensions.iconXLarge),
          ),
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