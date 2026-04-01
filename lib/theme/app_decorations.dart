/* App Decorations

   Central definition of reusable BoxDecorations and other
   decoration objects.
*/

import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_dimensions.dart';

class AppDecorations {
  AppDecorations._();

  // --- Background ---

  static const DecorationImage backgroundWatermark = DecorationImage(
    image: AssetImage('../lib/assets/images/Background/Watermerk.JPG'),
    fit: BoxFit.cover,
    alignment: Alignment.topCenter,
  );

  // --- Dark card (used in program list, info, chat list) ---

  static BoxDecoration darkCard({double radius = AppDimensions.radiusLarge}) =>
      BoxDecoration(
        color: AppColors.navyMedium,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white12, width: AppDimensions.borderThin),
      );

  // --- Light card (used in events, sponsors, home cards) ---

  static BoxDecoration lightCard({double radius = AppDimensions.radiusMedium}) =>
      BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
            color: AppColors.divider, width: AppDimensions.borderThin),
      );

  // --- Colored ApolloCard ---

  static BoxDecoration colorCard({
    required Color color,
    double radius = AppDimensions.radiusXLarge,
    Border? border,
  }) =>
      BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: border,
      );

  // --- Chat input field ---

  static const BoxDecoration chatInput = BoxDecoration(
    color: Color(0xFF102F52),
    borderRadius: BorderRadius.all(Radius.circular(AppDimensions.radiusMedium)),
    // Border added separately because Border.all isn't const-compatible with dynamic values,
    // but we keep this as a near-const baseline and callers can copyWith if needed.
  );

  static BoxDecoration chatInputFull() => BoxDecoration(
        color: AppColors.navyMedium,
        borderRadius:
            BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(
            color: Colors.white12, width: AppDimensions.borderThin),
      );

  // --- Chat message list container ---

  static BoxDecoration chatList() => BoxDecoration(
        color: AppColors.navyDeep,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXLarge),
        border: Border.all(
            color: Colors.white12, width: AppDimensions.borderThin),
      );

  // --- Live player card ---

  static BoxDecoration livePlayerCard() => BoxDecoration(
        color: AppColors.navyDark,
        borderRadius:
            BorderRadius.circular(AppDimensions.radiusXXLarge),
      );

  // --- LIVE badge ---

  static BoxDecoration liveBadge() => BoxDecoration(
        color: AppColors.live,
        borderRadius:
            BorderRadius.circular(AppDimensions.radiusFull),
      );

  // --- Icon container (used inside cards) ---

  static BoxDecoration iconContainer({
    required Color color,
    double radius = AppDimensions.radiusSmall,
  }) =>
      BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      );

  // --- Program card icon background ---

  static const BoxDecoration programIconBg = BoxDecoration(
    color: Colors.white12,
    borderRadius: BorderRadius.all(
        Radius.circular(AppDimensions.radiusSmall + 2)),
  );

  // --- Bottom nav bar ---

  static const BoxDecoration bottomNav = BoxDecoration(
    color: Color(0xFFF8FAFF),
    borderRadius: BorderRadius.only(
      topLeft: Radius.circular(AppDimensions.radiusXLarge),
      topRight: Radius.circular(AppDimensions.radiusXLarge),
    ),
  );

  // --- Chat bubble ---

  static BoxDecoration chatBubble({
    required bool isAdmin,
    required bool isUser,
  }) =>
      BoxDecoration(
        color: isAdmin
            ? AppColors.adminBadge
            : isUser
                ? AppColors.primaryLight
                : AppColors.white,
        borderRadius:
            BorderRadius.circular(AppDimensions.radiusMedium),
      );
}