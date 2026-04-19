/* App Colors

   Central definition of all colors used in the application.
*/

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand blues
  static const Color primary = Color(0xFF0A2342);
  static const Color primaryMid = Color(0xFF0A3D91);
  static const Color primaryLight = Color(0xFF185ADB);
  static const Color navyDark = Color(0xFF0D2F59);
  static const Color navyMedium = Color(0xFF102F52);
  static const Color navyDeep = Color(0xFF18375A);
  static const Color steelMedium = Color(0xFF2C4A6A);
  static const Color steelLight = Color(0xFF3A5F8A);

  // Card backgrounds
  static const Color cardYellow = Color(0xFFFFF4CE);
  static const Color cardBlue = Color(0xFFCDE7FF);
  static const Color cardGreen = Color(0xFFCBF0D8);

  // UI neutrals
  static const Color white = Colors.white;
  static const Color scaffoldBg = Colors.white;
  static const Color divider = Colors.black12;
  static const Color subtleText = Colors.black54;
  static const Color hintText = Colors.white54;

  // Accents
  static const Color live = Colors.red;
  static const Color adminBadge = Colors.orangeAccent;

  // ── Text on light backgrounds ─────────────────────────────────────────
  static const Color textPrimary = Colors.black;
  static const Color textBody = Colors.black87;
  static const Color textSecondary = Colors.black54;
  static const Color textMeta = Colors.black45;
  static const Color textHint = Colors.black26;

  // ── Text on dark backgrounds ──────────────────────────────────────────
  static const Color textOnDark = Colors.white;
  static const Color textOnDarkStrong = Colors.white;
  static const Color textOnDarkMedium = Colors.white70;
  static const Color textOnDarkMuted = Colors.white54;
  static const Color textOnDarkFaint = Colors.white38;

  // ── Overlays & borders on dark surfaces ───────────────────────────────
  static const Color borderSubtle = Colors.white12;
  static const Color overlayLight = Colors.white24;

  // ── Specific UI elements ──────────────────────────────────────────────
  static const Color bottomNavBg = Color(0xFFF8FAFF);
  static final Color stickyHeaderBg = Colors.white.withValues(alpha: 0.95);
  static const Color iconOnDarkMuted = Colors.white70;
  static const Color loadingIndicator = Colors.white38;
  static const Color liveDot = Colors.redAccent;
  static const Color charCounterWarn = Colors.redAccent;
  static const Color chevronIcon = Colors.black26;
  static const Color creditText = Color.fromARGB(204, 0, 0, 0);
  static const Color usernameLabel = Colors.white60;
  static const Color navUnselected = Colors.grey;

  // ── Offline banner ────────────────────────────────────────────────────
  static final Color offlineBannerBg = Colors.orange.shade100;
  static const Color offlineIcon = Colors.orange;
  static const Color offlineText = Colors.deepOrange;

  // ── Now-playing green dot ─────────────────────────────────────────────
  static final Color nowPlayingDot = Colors.greenAccent.shade400;
}
