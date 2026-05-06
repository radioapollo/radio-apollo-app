/* App Decorations

   Central definition of reusable BoxDecorations and other
   decoration objects.

   Theming
   ───────
   Surface decorations that need to flip between light/dark are
   getters that re-evaluate per call. They read AppColors, which
   delegates to the active palette in ThemeController.

   `backgroundWatermark` returns either the light or dark watermark
   asset. Anywhere it was previously used inside `const BoxDecoration(
   image: AppDecorations.backgroundWatermark)`, the `const` has been
   removed so the lookup happens at build time.

   `chatBubble` for non-user / non-admin messages used to be hardcoded
   to AppColors.white (a chat partner's bubble). On dark mode that
   left a glaring white rectangle on a black scaffold, so it now
   pulls the same raised surface used by the other "lightCard" treatments.
*/

import 'package:flutter/material.dart';
import '../services/theme/theme_controller.dart';
import 'app_colors.dart';
import 'app_dimensions.dart';

class AppDecorations {
  AppDecorations._();

  static const AssetImage _watermarkLight = AssetImage(
    'assets/images/Background/Watermerk.JPG',
  );
  static const AssetImage _watermarkDark = AssetImage(
    'assets/images/Background/Watermerk_dark.JPG',
  );

  // ── Themed page background ────────────────────────────────────────────────

  static DecorationImage get backgroundWatermark => DecorationImage(
    image: ThemeController.instance.isDark ? _watermarkDark : _watermarkLight,
    fit: BoxFit.cover,
    alignment: Alignment.topCenter,
  );

  // ── Brand-fixed cards (navy surface in both modes) ───────────────────────
  // These carry white text and stay on-brand regardless of theme.

  static BoxDecoration darkCard({double radius = AppDimensions.radiusLarge}) =>
      BoxDecoration(
        color: AppColors.navyMedium,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: AppColors.borderSubtle,
          width: AppDimensions.borderThin,
        ),
      );

  static BoxDecoration currentProgramCard() => BoxDecoration(
    color: AppColors.primaryLight,
    borderRadius: BorderRadius.circular(AppDimensions.radiusXLarge),
    border: Border.all(
      color: AppColors.overlayLight,
      width: AppDimensions.borderThin,
    ),
  );

  static BoxDecoration nuBezigBadge() => BoxDecoration(
    color: AppColors.overlayLight,
    borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
  );

  // ── Themed surface cards (flip with the theme) ───────────────────────────
  // Light: white. Dark: a slightly raised dark surface that sits on top
  // of the near-black scaffold.

  static const Color _darkRaisedSurface = Color(0xFF1A2438);

  static Color get _surfaceFill =>
      ThemeController.instance.isDark ? _darkRaisedSurface : AppColors.white;

  static BoxDecoration lightCard({
    double radius = AppDimensions.radiusMedium,
  }) => BoxDecoration(
    color: _surfaceFill,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: AppColors.divider,
      width: AppDimensions.borderThin,
    ),
  );

  // Variant of lightCard with optional shadow + override-able border colour
  // for the event card's "boxShadow on upcoming" treatment.
  static BoxDecoration eventSurfaceCard({
    double radius = AppDimensions.radiusMedium,
    List<BoxShadow>? boxShadow,
  }) => BoxDecoration(
    color: _surfaceFill,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: AppColors.divider,
      width: AppDimensions.borderThin,
    ),
    boxShadow: boxShadow,
  );

  static BoxDecoration colorCard({
    required Color color,
    double radius = AppDimensions.radiusXLarge,
    Border? border,
  }) => BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(radius),
    border: border,
  );

  static BoxDecoration chatInputFull() => BoxDecoration(
    color: AppColors.navyMedium,
    borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
    border: Border.all(
      color: AppColors.borderSubtle,
      width: AppDimensions.borderThin,
    ),
  );

  static BoxDecoration chatList() => BoxDecoration(
    color: AppColors.navyDeep,
    borderRadius: BorderRadius.circular(AppDimensions.radiusXLarge),
    border: Border.all(
      color: AppColors.borderSubtle,
      width: AppDimensions.borderThin,
    ),
  );

  static BoxDecoration livePlayerCard() => BoxDecoration(
    color: AppColors.navyDark,
    borderRadius: BorderRadius.circular(AppDimensions.radiusXXLarge),
  );

  static BoxDecoration liveBadge() => BoxDecoration(
    color: AppColors.live,
    borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
  );

  static BoxDecoration iconContainer({
    required Color color,
    double radius = AppDimensions.radiusSmall,
  }) =>
      BoxDecoration(color: color, borderRadius: BorderRadius.circular(radius));

  static const BoxDecoration programIconBg = BoxDecoration(
    color: AppColors.borderSubtle,
    borderRadius: BorderRadius.all(
      Radius.circular(AppDimensions.radiusSmall + 2),
    ),
  );

  static BoxDecoration stickyHeader() =>
      BoxDecoration(color: AppColors.stickyHeaderBg);

  // Bottom nav follows the theme.
  static BoxDecoration get bottomNav => BoxDecoration(
    color: AppColors.bottomNavBg,
    borderRadius: const BorderRadius.only(
      topLeft: Radius.circular(AppDimensions.radiusXLarge),
      topRight: Radius.circular(AppDimensions.radiusXLarge),
    ),
  );

  // Chat bubbles
  // ────────────
  // Admin: orange (brand-fixed).
  // User (your own messages): primary blue (brand-fixed).
  // Other user: themed surface — white on light mode, dark raised
  // surface on dark mode. The text inside is `AppColors.textBody`,
  // which is also themed, so the contrast holds in both modes.
  static BoxDecoration chatBubble({
    required bool isAdmin,
    required bool isUser,
  }) => BoxDecoration(
    color: isAdmin
        ? AppColors.adminBadge
        : isUser
        ? AppColors.primaryLight
        : _surfaceFill,
    borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
  );
}