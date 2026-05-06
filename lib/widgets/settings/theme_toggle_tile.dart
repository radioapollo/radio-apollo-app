/* Theme Toggle Tile

   The visual control for the "Weergave" section on the Settings
   screen. A simple two-option segmented control: Licht / Donker.

   Listens to ThemeController via AnimatedBuilder so the selected
   pill always reflects the current state, even if the theme were
   ever toggled from elsewhere in the app.
*/

import 'package:flutter/material.dart';
import '../../services/theme/theme_controller.dart';
import '../../theme/app_theme.dart';

class ThemeToggleTile extends StatelessWidget {
  const ThemeToggleTile({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (context, _) {
        final isDark = ThemeController.instance.isDark;
        return Padding(
          padding: const EdgeInsets.only(bottom: AppDimensions.spaceMedium),
          child: Row(
            children: [
              Expanded(
                child: _ThemeOption(
                  icon: Icons.light_mode_outlined,
                  label: 'Licht',
                  selected: !isDark,
                  onTap: () =>
                      ThemeController.instance.setMode(AppThemeMode.light),
                ),
              ),
              const SizedBox(width: AppDimensions.spaceMedium),
              Expanded(
                child: _ThemeOption(
                  icon: Icons.dark_mode_outlined,
                  label: 'Donker',
                  selected: isDark,
                  onTap: () =>
                      ThemeController.instance.setMode(AppThemeMode.dark),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Selected pill uses the brand primaryLight; unselected pulls
    // the themed lightCard so it sits comfortably on either bg.
    final fg = selected ? AppColors.textOnDark : AppColors.textBody;

    return InkWell(
      borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingLarge,
          vertical: AppDimensions.paddingMedium,
        ),
        decoration: selected
            ? BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
              )
            : AppDecorations.lightCard(),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: AppDimensions.iconMedium, color: fg),
            const SizedBox(width: AppDimensions.spaceSmall),
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}