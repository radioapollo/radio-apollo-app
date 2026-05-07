/* Themed Logo

   Renders the Radio Apollo logo. Both light and dark logo variants
   are kept mounted in the widget tree at all times — only their
   opacity flips when the theme changes — so there's no PNG decode
   gap when toggling themes.

   Use this anywhere we previously did:

     Image.asset(
       AppAssets.logo,
       height: AppDimensions.logoHeight,
       fit: BoxFit.contain,
     )

   …and replace with:

     ThemedLogo(height: AppDimensions.logoHeight)
*/

import 'package:flutter/material.dart';
import '../services/theme/theme_controller.dart';

class ThemedLogo extends StatelessWidget {
  final double height;
  final BoxFit fit;

  const ThemedLogo({
    super.key,
    required this.height,
    this.fit = BoxFit.contain,
  });

  static const _logoLight = AssetImage('assets/images/Logo/transparant.png');
  static const _logoDark = AssetImage(
    'assets/images/Logo/transparant_dark.png',
  );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (context, _) {
        final isDark = ThemeController.instance.isDark;
        return SizedBox(
          height: height,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Image(
                image: _logoLight,
                height: height,
                fit: fit,
                opacity: AlwaysStoppedAnimation(isDark ? 0.0 : 1.0),
              ),
              Image(
                image: _logoDark,
                height: height,
                fit: fit,
                opacity: AlwaysStoppedAnimation(isDark ? 1.0 : 0.0),
              ),
            ],
          ),
        );
      },
    );
  }
}
