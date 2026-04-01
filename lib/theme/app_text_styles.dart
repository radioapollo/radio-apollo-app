/* App Text Styles

   Central definition of all text styles used in the application.
*/

import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  // Screen headings
  static const TextStyle screenTitle = TextStyle(
    color: Colors.black,
    fontSize: 26,
    fontWeight: FontWeight.w800,
  );

  static const TextStyle screenTitleSmall = TextStyle(
    color: Colors.black,
    fontSize: 24,
    fontWeight: FontWeight.w700,
  );

  // Chat header
  static const TextStyle chatTitle = TextStyle(
    color: Colors.black,
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
    color: Colors.black87,
    fontSize: 16,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle cardSubtitle = TextStyle(
    color: Colors.black54,
    height: 1.3,
    fontSize: 13,
  );

  static const TextStyle cardMeta = TextStyle(
    color: Colors.black45,
    fontSize: 12,
  );

  // Cards (dark background)
  static const TextStyle darkCardTitle = TextStyle(
    color: Colors.white,
    fontSize: 18,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle darkCardTime = TextStyle(
    color: Colors.white54,
    fontSize: 13,
  );

  static const TextStyle darkCardSubtitle = TextStyle(
    color: Colors.white70,
    fontSize: 14,
    height: 1.3,
  );

  static const TextStyle darkCardBody = TextStyle(
    color: Colors.white70,
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
    color: Colors.white,
    fontSize: 12,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle stationName = TextStyle(
    color: Colors.white,
    fontSize: 22,
    height: 1.2,
    fontWeight: FontWeight.w800,
  );

  static const TextStyle playerArtist = TextStyle(
    color: Colors.white,
    fontSize: 13,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle playerSong = TextStyle(
    color: Colors.white70,
    fontSize: 13,
  );

  // Day selector
  static const TextStyle dayLabel = TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.w600,
  );

  // Chat bubbles
  static const TextStyle bubbleText = TextStyle(
    fontSize: 15,
  );

  static const TextStyle bubbleTime = TextStyle(
    color: Colors.white54,
    fontSize: 11,
  );

  // Input field
  static const TextStyle inputText = TextStyle(color: Colors.white);

  static const TextStyle inputHint = TextStyle(color: Colors.white54);

  static const TextStyle noDataText = TextStyle(color: Colors.black54);
}