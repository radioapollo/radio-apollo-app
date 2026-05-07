/* Theme Toggle Tile

   A single segmented switch for choosing Light / Dark.
   The whole control is one track with a sliding pill that animates
   between the sun (left) and moon (right) positions.

   Listens to ThemeController via AnimatedBuilder so the pill always
   reflects the current state, even if the theme were ever toggled
   from elsewhere in the app.
*/

import 'package:flutter/material.dart';
import '../../services/theme/theme_controller.dart';
import '../../theme/app_theme.dart';

class ThemeToggleTile extends StatelessWidget {
  const ThemeToggleTile({super.key});

  static const _animationDuration = Duration(milliseconds: 280);
  static const _trackHeight = 52.0;
  static const _trackPadding = 4.0;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (context, _) {
        final isDark = ThemeController.instance.isDark;

        return Padding(
          padding: const EdgeInsets.only(bottom: AppDimensions.spaceMedium),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final pillWidth = (constraints.maxWidth - _trackPadding * 2) / 2;

              return Container(
                height: _trackHeight,
                padding: const EdgeInsets.all(_trackPadding),
                decoration: AppDecorations.lightCard(),
                child: Stack(
                  children: [
                    // Sliding selection pill
                    AnimatedAlign(
                      duration: _animationDuration,
                      curve: Curves.easeInOutCubic,
                      alignment: isDark
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        width: pillWidth,
                        height: _trackHeight - _trackPadding * 2,
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusMedium,
                          ),
                        ),
                      ),
                    ),

                    // Tappable labels stacked on top of the pill
                    Row(
                      children: [
                        Expanded(
                          child: _ThemeOption(
                            icon: Icons.light_mode_outlined,
                            label: 'Licht',
                            selected: !isDark,
                            onTap: () => ThemeController.instance.setMode(
                              AppThemeMode.light,
                            ),
                          ),
                        ),
                        Expanded(
                          child: _ThemeOption(
                            icon: Icons.dark_mode_outlined,
                            label: 'Donker',
                            selected: isDark,
                            onTap: () => ThemeController.instance.setMode(
                              AppThemeMode.dark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
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
    final fg = selected ? AppColors.textOnDark : AppColors.textBody;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        onTap: onTap,
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<Color?>(
                duration: ThemeToggleTile._animationDuration,
                tween: ColorTween(end: fg),
                builder: (context, color, _) {
                  return Icon(icon, size: 18, color: color);
                },
              ),
              const SizedBox(width: AppDimensions.spaceSmall),
              AnimatedDefaultTextStyle(
                duration: ThemeToggleTile._animationDuration,
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
