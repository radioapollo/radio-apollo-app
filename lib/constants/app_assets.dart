/* App Assets
   Central definition of all asset paths used
   throughout the application.

   Theming
   ───────
   Logo is now a getter that picks the right variant for the current
   theme. We can't import ThemeController here without a circular
   dep risk through theme files, but it's a safe one-way reference:
   theme files import ThemeController too, but never import this file.

   To change the dark logo, replace transparant_dark.png and keep the
   filename. The file is shipped under assets/images/Logo/.
*/

import '../services/theme/theme_controller.dart';

class AppAssets {
  AppAssets._();

  // ── Logo ──────────────────────────────────────────────────────────────────
  // Light: dark navy + brand-blue lettering on a white scaffold.
  // Dark : same composition with the dark-navy parts remapped to off-white
  //        so the lettering reads against the near-black scaffold; the
  //        brand-blue parts stay unchanged in both modes.
  static String get logo => ThemeController.instance.isDark
      ? 'assets/images/Logo/transparant_dark.png'
      : 'assets/images/Logo/transparant.png';

  // ── Watermark ─────────────────────────────────────────────────────────────
  // The light watermark; the dark variant is referenced directly inside
  // AppDecorations.backgroundWatermark since callers normally use the
  // decoration helper rather than the raw path.
  static const String watermark = 'assets/images/Background/Watermerk.JPG';
}