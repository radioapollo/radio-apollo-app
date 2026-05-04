/* App Decorations

   Central definition of reusable BoxDecorations and other
   decoration objects.
*/

import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_dimensions.dart';

class AppDecorations {
  AppDecorations._();

  static const DecorationImage backgroundWatermark = DecorationImage(
    image: AssetImage('assets/images/Background/Watermerk.JPG'),
    fit: BoxFit.cover,
    alignment: Alignment.topCenter,
  );

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

  static BoxDecoration lightCard({
    double radius = AppDimensions.radiusMedium,
  }) => BoxDecoration(
    color: AppColors.white,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: AppColors.divider,
      width: AppDimensions.borderThin,
    ),
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

  static const BoxDecoration bottomNav = BoxDecoration(
    color: AppColors.bottomNavBg,
    borderRadius: BorderRadius.only(
      topLeft: Radius.circular(AppDimensions.radiusXLarge),
      topRight: Radius.circular(AppDimensions.radiusXLarge),
    ),
  );

  static BoxDecoration chatBubble({
    required bool isAdmin,
    required bool isUser,
  }) => BoxDecoration(
    color: isAdmin
        ? AppColors.adminBadge
        : isUser
        ? AppColors.primaryLight
        : AppColors.white,
    borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
  );
}
