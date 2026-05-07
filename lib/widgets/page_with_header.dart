/* Page With Header Widget

   This widget provides a consistent page layout
   used across multiple screens.

   It includes:
   - the Radio Apollo logo header
   - a background watermark image (themed: light or dark variant,
     swapped via ThemedWatermarkBackground so there's no decode gap
     when flipping themes)
   - consistent padding and scrolling behaviour
*/

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'themed_watermark_background.dart';
import '../widgets/themed_logo.dart';

class PageWithHeader extends StatelessWidget {
  final Widget child;

  const PageWithHeader({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ThemedWatermarkBackground(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.paddingXLarge,
            AppDimensions.paddingXLarge,
            AppDimensions.paddingXLarge,
            AppDimensions.space30,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ThemedLogo(height: AppDimensions.logoHeight),
              const SizedBox(height: AppDimensions.spaceMedium),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
