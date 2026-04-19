/* App Dimensions

   Central definition of spacing, sizing, and border radius values.
*/

class AppDimensions {
  AppDimensions._();

  // Border radii
  static const double radiusSmall = 14.0;
  static const double radiusMedium = 18.0;
  static const double radiusLarge = 20.0;
  static const double radiusXLarge = 22.0;
  static const double radiusXXLarge = 24.0;
  static const double radiusPill = 30.0;
  static const double radiusFull = 50.0;

  // Padding
  static const double paddingSmall = 12.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 18.0;
  static const double paddingXLarge = 20.0;

  // Spacing (SizedBox heights/widths)
  static const double spaceXSmall = 4.0;
  static const double spaceSmall = 6.0;
  static const double spaceMedium = 10.0;
  static const double spaceLarge = 14.0;
  static const double spaceXLarge = 16.0;
  static const double spaceXXLarge = 18.0;
  static const double space25 = 25.0;
  static const double space30 = 30.0;

  // Component sizes
  static const double logoHeight = 60.0;
  static const double daySelectorHeight = 50.0;
  static const double daySelectorItemWidth = 110.0;
  static const double daySelectorSpacing = 12.0;

  // Border widths
  static const double borderThin = 1.5;

  // Icon sizes
  static const double iconSmall = 13.0;
  static const double iconMedium = 18.0;
  static const double iconLarge = 26.0;
  static const double iconXLarge = 32.0;
  static const double iconXXLarge = 36.0;
  static const double iconPlayer = 42.0;
  static const double iconPlayPause = 70.0;

  // Program card
  static const double programCardHeight = 108.0;
  static const double nuBezigBadgePaddingH = 8.0;
  static const double nuBezigBadgePaddingV = 3.0;
  static const double nuBezigIconSize = 8.0;
  static const double nuBezigFontSize = 11.0;
  static const double nuBezigIconSpacing = 4.0;

  // Sticky header
  static const double stickyHeaderHeight =
      logoHeight +
      space30 +
      40.0 + // title text
      spaceXLarge +
      daySelectorHeight +
      paddingXLarge * 2;
}
