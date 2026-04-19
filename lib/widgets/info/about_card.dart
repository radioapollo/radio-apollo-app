/* About Card Widget

   A simple dark-themed card that displays the station's
   "about" paragraph fetched from Firestore.
*/

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class AboutCard extends StatelessWidget {
  final String text;

  const AboutCard({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:    const EdgeInsets.all(AppDimensions.paddingLarge),
      decoration: AppDecorations.darkCard(),
      child:      Text(text, style: AppTextStyles.darkCardBody),
    );
  }
}