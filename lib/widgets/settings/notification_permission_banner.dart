/* Notification Permission Banner

   Shown above the notification toggle list on the Settings screen
   when there's something the user needs to know about OS-level
   notification permission.

   Two states render a banner:

   - notYetAsked : we haven't gotten permission from the OS yet
                   (fresh install, dismissed prompt, etc). Button
                   triggers the OS prompt directly.
   - denied      : permission was refused or turned off in system
                   settings. The OS prompt won't reappear in this
                   state, so the button opens system settings.

   In every other case (`none`) the banner returns SizedBox.shrink()
   and the toggles below are the only UI.

   Why two states instead of always pointing to system settings?
   ─────────────────────────────────────────────────────────────
   Sending a fresh-install user to "Open instellingen" is hostile —
   it's three taps deep and they have no idea why. The OS prompt is
   one tap. We use the prompt whenever it's still possible (i.e.
   we've never been refused), and only fall back to system settings
   when there's no other choice.

   Uses the `app_settings` plugin for the system-settings deep link
   because it handles the platform differences (Android per-app
   notifications page vs iOS app settings).
*/

import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';

import '../../services/notifications/notification_service.dart';
import '../../theme/app_theme.dart';

class NotificationPermissionBanner extends StatelessWidget {
  final PermissionBannerState state;

  final Future<void> Function() onRequestPermission;

  const NotificationPermissionBanner({
    super.key,
    required this.state,
    required this.onRequestPermission,
  });

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case PermissionBannerState.none:
        return const SizedBox.shrink();

      case PermissionBannerState.notYetAsked:
        return _buildBanner(
          icon: Icons.notifications_active_outlined,
          color: AppColors.primaryLight,
          title: 'Meldingen staan nog uit',
          body:
              'Schakel meldingen in om een seintje te krijgen wanneer de '
              'studio antwoordt of een evenement eraan zit te komen.',
          actionLabel: 'Inschakelen',
          onAction: onRequestPermission,
        );

      case PermissionBannerState.denied:
        return _buildBanner(
          icon: Icons.notifications_off_outlined,
          color: AppColors.offlineIcon,
          title: 'Meldingen staan uit',
          body:
              'Meldingen zijn uitgeschakeld in de telefooninstellingen. '
              'De schakelaars hieronder doen voorlopig niets.',
          actionLabel: 'Open instellingen',
          onAction: () =>
              AppSettings.openAppSettings(type: AppSettingsType.notification),
        );
    }
  }

  Widget _buildBanner({
    required IconData icon,
    required Color color,
    required String title,
    required String body,
    required String actionLabel,
    required Future<void> Function() onAction,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.spaceXLarge),
      padding: const EdgeInsets.all(AppDimensions.paddingMedium),
      decoration: AppDecorations.lightCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: AppDimensions.iconLarge),
              const SizedBox(width: AppDimensions.spaceMedium),
              Expanded(child: Text(title, style: AppTextStyles.cardTitle)),
            ],
          ),
          const SizedBox(height: AppDimensions.spaceMedium),
          Text(body, style: AppTextStyles.cardSubtitle),
          const SizedBox(height: AppDimensions.spaceMedium),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              style: TextButton.styleFrom(foregroundColor: color),
              onPressed: () => onAction(),
              child: Text(actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}
