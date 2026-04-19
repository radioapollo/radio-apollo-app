/* App Version Footer

   Shown at the bottom of the info screen.
   Displays the developer credit and the current app version.

   The version is read from AppConstants.appVersion — update there
   when you bump the version in pubspec.yaml.
*/

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../constants/constants.dart';

class AppVersionFooter extends StatelessWidget {
  const AppVersionFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Center(
          child: Text(
            'App ontwikkeld door Raf Vermeylen',
            style: TextStyle(
              color:      AppColors.creditText,
              fontSize:   12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.spaceSmall),
        Center(
          child: Text(
            'Versie ${AppConstants.appVersion}',
            style: const TextStyle(
              color:    AppColors.creditText,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }
}