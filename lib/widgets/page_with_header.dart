/* Page With Header Widget

   This widget provides a consistent page layout
   used across multiple screens.

   It includes:
   - the Radio Apollo logo header
   - a background watermark image
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
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(AppAssets.watermark),
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.paddingXLarge,
              AppDimensions.paddingXLarge,
              AppDimensions.paddingXLarge,
              30,
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