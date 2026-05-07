/* Themed Watermark Background

   Renders the page-wide watermark image. Both light and dark
   watermark variants are kept mounted in the widget tree at all
   times — only their opacity flips when the theme changes — so
   there's no JPG decode gap when toggling themes.
*/

import 'package:flutter/material.dart';
import '../services/theme/theme_controller.dart';

class ThemedWatermarkBackground extends StatelessWidget {
  final Widget child;

  const ThemedWatermarkBackground({super.key, required this.child});

  static const _watermarkLight = AssetImage(
    'assets/images/Background/Watermerk.JPG',
  );
  static const _watermarkDark = AssetImage(
    'assets/images/Background/Watermerk_dark.JPG',
  );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (context, _) {
        final isDark = ThemeController.instance.isDark;
        return Stack(
          children: [
            // Both images are always mounted. The "off" one is fully
            // transparent but still in memory, so flipping themes is
            // a pure opacity change — no decode gap.
            Positioned.fill(
              child: Image(
                image: _watermarkLight,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                opacity: AlwaysStoppedAnimation(isDark ? 0.0 : 1.0),
              ),
            ),
            Positioned.fill(
              child: Image(
                image: _watermarkDark,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                opacity: AlwaysStoppedAnimation(isDark ? 1.0 : 0.0),
              ),
            ),
            Positioned.fill(child: child),
          ],
        );
      },
    );
  }
}
