/* App Colors

   Central definition of all colors used in the application.
*/

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand blues
  static const Color primary       = Color(0xFF0A2342);
  static const Color primaryMid    = Color(0xFF0A3D91);
  static const Color primaryLight  = Color(0xFF185ADB);
  static const Color navyDark      = Color(0xFF0D2F59);
  static const Color navyMedium    = Color(0xFF102F52);
  static const Color navyDeep      = Color(0xFF18375A);
  static const Color steelMedium   = Color(0xFF2C4A6A);
  static const Color steelLight    = Color(0xFF3A5F8A);

  // Card backgrounds
  static const Color cardYellow    = Color(0xFFFFF4CE);
  static const Color cardBlue      = Color(0xFFCDE7FF);
  static const Color cardGreen     = Color(0xFFCBF0D8);

  // UI neutrals
  static const Color white         = Colors.white;
  static const Color scaffoldBg    = Colors.white;
  static const Color divider       = Colors.black12;
  static const Color subtleText    = Colors.black54;
  static const Color hintText      = Colors.white54;

  // Accents
  static const Color live          = Colors.red;
  static const Color adminBadge    = Colors.orangeAccent;
}