/* App Text Styles

   Central definition of all text styles used in the application.
*/

import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_dimensions.dart';

class AppTextStyles {
  AppTextStyles._();

  // Screen headings
  static const TextStyle screenTitle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 26,
    fontWeight: FontWeight.w800,
  );

  static const TextStyle screenTitleSmall = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 24,
    fontWeight: FontWeight.w700,
  );

  // Chat header
  static const TextStyle chatTitle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 22,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle adminBadge = TextStyle(
    color: AppColors.adminBadge,
    fontSize: 12,
    fontWeight: FontWeight.bold,
  );

  // Cards (light background)
  static const TextStyle cardTitle = TextStyle(
    color: AppColors.textBody,
    fontSize: 16,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle cardSubtitle = TextStyle(
    color: AppColors.textSecondary,
    height: 1.3,
    fontSize: 13,
  );

  static const TextStyle cardMeta = TextStyle(
    color: AppColors.textMeta,
    fontSize: 12,
  );

  // Cards (dark background)
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

  // ApolloCard vertical/horizontal labels
  static const TextStyle apolloCardTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w800,
  );

  static const TextStyle apolloCardSubtitle = TextStyle(
    fontSize: 15,
    height: 1.3,
    fontWeight: FontWeight.w600,
  );

  // Live player
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

  // Day selector
  static const TextStyle dayLabel = TextStyle(
    color: AppColors.textOnDark,
    fontWeight: FontWeight.w600,
  );

  // Chat bubbles
  static const TextStyle bubbleText = TextStyle(fontSize: 15);

  static const TextStyle bubbleTime = TextStyle(
    color: AppColors.textOnDarkMuted,
    fontSize: 11,
  );

  // Input field
  static const TextStyle inputText = TextStyle(color: AppColors.textOnDark);

  static const TextStyle inputHint = TextStyle(
    color: AppColors.textOnDarkMuted,
  );

  static const TextStyle noDataText = TextStyle(color: AppColors.textSecondary);

  // Nu bezig badge
  static const TextStyle nuBezigLabel = TextStyle(
    color: AppColors.textOnDark,
    fontSize: AppDimensions.nuBezigFontSize,
    fontWeight: FontWeight.bold,
  );
}
