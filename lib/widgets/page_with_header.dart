/* Page With Header Widget

   This widget provides a consistent page layout
   used across multiple screens.

   It includes:
   - the Radio Apollo logo header
   - a background watermark image (themed: light or dark variant)
   - consistent padding and scrolling behaviour
*/

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../constants/constants.dart';

class PageWithHeader extends StatelessWidget {
  final Widget child;

  const PageWithHeader({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Container(
        // Non-const: AppDecorations.backgroundWatermark is a getter that
        // resolves to the active palette's watermark asset.
        decoration: BoxDecoration(
          image: AppDecorations.backgroundWatermark,
        ),
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
                Image.asset(
                  AppAssets.logo,
                  height: AppDimensions.logoHeight,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: AppDimensions.spaceMedium),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}