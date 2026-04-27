/* Notification Toggle Tile

   A single row in the notification settings list: title, one-line
   description, and a Switch on the right. Used once per
   NotificationCategory.

   Pure presentation — all state and callbacks live on the parent
   SettingsScreen. We deliberately avoid SwitchListTile here so the
   styling matches the rest of the app's card-on-watermark look
   instead of falling back to the default Material list-tile padding.
*/

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class NotificationToggleTile extends StatelessWidget {
  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  const NotificationToggleTile({
    super.key,
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.spaceLarge),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingMedium,
        vertical: AppDimensions.paddingSmall,
      ),
      decoration: AppDecorations.lightCard(),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.cardTitle),
                const SizedBox(height: AppDimensions.spaceXSmall),
                Text(description, style: AppTextStyles.cardSubtitle),
              ],
            ),
          ),
          const SizedBox(width: AppDimensions.spaceMedium),
          Switch.adaptive(
            value: value,
            activeThumbColor: AppColors.primaryLight,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}