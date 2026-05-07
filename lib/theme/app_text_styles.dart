/* App Text Styles

   Central definition of all text styles used in the application.

   Theming
   ───────
   Styles whose color comes from a themed slot (textPrimary,
   textBody, textSecondary, textMeta) can no longer be `const` —
   they're built from getters now. Styles whose color is
   brand-fixed (white-on-dark for the navy player card, the
   admin orange badge, the live label) stay `const`.

   Practical effect on call-sites: previously `const Text(..., style:
   AppTextStyles.screenTitle)` worked. Now the style itself isn't
   const, so the surrounding `const` widget literal must drop the
   const keyword. The analyzer pinpoints every site automatically;
   the fix is mechanical (delete `const`).
*/

import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_dimensions.dart';

class AppTextStyles {
  AppTextStyles._();

  // ── Themed (page-bg-dependent) styles — non-const ─────────────────────────

  static TextStyle get screenTitle => TextStyle(
    color: AppColors.textPrimary,
    fontSize: 26,
    fontWeight: FontWeight.w800,
  );

  static TextStyle get screenTitleSmall => TextStyle(
    color: AppColors.textPrimary,
    fontSize: 24,
    fontWeight: FontWeight.w700,
  );

  static TextStyle get chatTitle => TextStyle(
    color: AppColors.textPrimary,
    fontSize: 22,
    fontWeight: FontWeight.w700,
  );

  static TextStyle get cardTitle => TextStyle(
    color: AppColors.textBody,
    fontSize: 16,
    fontWeight: FontWeight.w700,
  );

  static TextStyle get cardSubtitle =>
      TextStyle(color: AppColors.textSecondary, height: 1.3, fontSize: 13);

  static TextStyle get cardMeta =>
      TextStyle(color: AppColors.textMeta, fontSize: 12);

  static TextStyle get noDataText => TextStyle(color: AppColors.textSecondary);

  // ── Brand-fixed styles — still const ──────────────────────────────────────

  static const TextStyle adminBadge = TextStyle(
    color: AppColors.adminBadge,
    fontSize: 12,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle darkCardTitle = TextStyle(
    color: AppColors.textOnDark,
    fontSize: 18,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle darkCardTime = TextStyle(
    color: AppColors.textOnDarkMuted,
    fontSize: 13,
  );

  static const TextStyle darkCardSubtitle = TextStyle(
    color: AppColors.textOnDarkMedium,
    fontSize: 14,
    height: 1.3,
  );

  static const TextStyle darkCardBody = TextStyle(
    color: AppColors.textOnDarkMedium,
    height: 1.4,
  );

  // Apollo home cards specify their own colour via copyWith at the call
  // site, so these stay const.
  static const TextStyle apolloCardTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w800,
  );

  static const TextStyle apolloCardSubtitle = TextStyle(
    fontSize: 15,
    height: 1.3,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle liveLabel = TextStyle(
    color: AppColors.textOnDark,
    fontSize: 12,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle stationName = TextStyle(
    color: AppColors.textOnDark,
    fontSize: 22,
    height: 1.2,
    fontWeight: FontWeight.w800,
  );

  static const TextStyle playerArtist = TextStyle(
    color: AppColors.textOnDark,
    fontSize: 13,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle playerSong = TextStyle(
    color: AppColors.textOnDarkMedium,
    fontSize: 13,
  );

  static const TextStyle dayLabel = TextStyle(
    color: AppColors.textOnDark,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle bubbleText = TextStyle(fontSize: 15);

  static const TextStyle bubbleTime = TextStyle(
    color: AppColors.textOnDarkMuted,
    fontSize: 11,
  );

  static const TextStyle inputText = TextStyle(color: AppColors.textOnDark);

  static const TextStyle inputHint = TextStyle(
    color: AppColors.textOnDarkMuted,
  );

  static const TextStyle nuBezigLabel = TextStyle(
    color: AppColors.textOnDark,
    fontSize: AppDimensions.nuBezigFontSize,
    fontWeight: FontWeight.bold,
  );
}
