/* Program Card Widget

   This widget displays a single radio program in the schedule.

   It shows:
   - the broadcast time
   - the program title
   - a short description
*/

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ProgramCard extends StatelessWidget {
  final String time;
  final String title;
  final String subtitle;
  final Border? border;

  const ProgramCard({
    super.key,
    required this.time,
    required this.title,
    required this.subtitle,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.paddingLarge),
      padding: const EdgeInsets.all(AppDimensions.paddingXLarge),
      decoration: AppDecorations.darkCard(radius: AppDimensions.radiusXLarge),
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
                Text(time, style: AppTextStyles.darkCardTime),
                const SizedBox(height: AppDimensions.spaceXSmall),
                Text(title, style: AppTextStyles.darkCardTitle),
                const SizedBox(height: AppDimensions.spaceXSmall),
                Text(subtitle, style: AppTextStyles.darkCardSubtitle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}