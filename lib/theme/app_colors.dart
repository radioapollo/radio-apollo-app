/* App Colors

   Central definition of all colors used in the application.

   Light/Dark theming
   ──────────────────
   This file used to be a flat list of `static const Color` fields.
   To support runtime theme switching we now expose colors as
   `static` getters that delegate to either `_LightPalette` or
   `_DarkPalette` based on `ThemeController.instance.isDark`.

   Consequence: any widget that previously embedded a colour in a
   `const TextStyle(...)` or `const Icon(...)` constructor must drop
   the `const` — getters can't be used in const expressions. The
   analyzer flags every site automatically.

   Colors that genuinely never change (brand-fixed shades like
   primaryLight used as accent fills, or the live-red for the LIVE
   badge) stay as compile-time constants. We only theme the palette
   slots that actually need to flip — surfaces, text, dividers,
   subtle backgrounds.

   To add a new themed color: declare it in both _LightPalette and
   _DarkPalette, then expose a getter on AppColors that reads from
   `_active`.
*/

import 'package:flutter/material.dart';
import '../services/theme/theme_controller.dart';

// ── Brand-fixed constants (identical in both modes) ──────────────────────────
// These represent the radio's brand identity — the navy used in the live
// player card, the primary accent blue, the card colours on the home grid.
// They are visually meaningful regardless of background and shouldn't shift
// with the theme, so we keep them as plain `const`.

class AppColors {
  AppColors._();

  // Brand identity — fixed
  static const Color primary = Color(0xFF0A2342);
  static const Color primaryMid = Color(0xFF0A3D91);
  static const Color primaryLight = Color(0xFF185ADB);
  static const Color navyDark = Color(0xFF0D2F59);
  static const Color navyMedium = Color(0xFF102F52);
  static const Color navyDeep = Color(0xFF18375A);
  static const Color steelMedium = Color(0xFF2C4A6A);
  static const Color steelLight = Color(0xFF3A5F8A);

  static const Color cardYellow = Color(0xFFFFF4CE);
  static const Color cardBlue = Color(0xFFCDE7FF);
  static const Color cardGreen = Color(0xFFCBF0D8);

  static const Color white = Colors.white;
  static const Color hintText = Colors.white54;

  static const Color live = Colors.red;
  static const Color adminBadge = Colors.orangeAccent;

  // Studio account — green, brand-fixed. studioBubble fills the green
  // "Studio" chat bubble; studioBadge is the darker green used for the
  // "STUDIO MODE" text indicator (needs more contrast against the page
  // background than the bubble fill does). We use dark text on the
  // studioBubble fill, same treatment as the orange admin bubble.
  static const Color studioBubble = Color(0xFF66BB6A);
  static const Color studioBadge = Color(0xFF2E7D32);

  // Text on dark surfaces — these stay constant because the dark cards
  // (live player, program cards, chat input) keep their navy fill in
  // both modes; the text on top is always white.
  static const Color textOnDark = Colors.white;
  static const Color textOnDarkStrong = Colors.white;
  static const Color textOnDarkMedium = Colors.white70;
  static const Color textOnDarkMuted = Colors.white54;
  static const Color textOnDarkFaint = Colors.white38;

  // Overlays & borders on dark surfaces — also constant
  static const Color borderSubtle = Colors.white12;
  static const Color overlayLight = Colors.white24;

  // Misc constants
  static const Color iconOnDarkMuted = Colors.white70;
  static const Color loadingIndicator = Colors.white38;
  static const Color liveDot = Colors.redAccent;
  static const Color charCounterWarn = Colors.redAccent;
  static const Color usernameLabel = Colors.white60;
  static const Color navUnselected = Colors.grey;
  static const Color offlineIcon = Colors.orange;
  static const Color offlineText = Colors.deepOrange;

  // ── Themed slots ───────────────────────────────────────────────────────────
  // Resolve via the active palette. Re-evaluated on every read, so when
  // ThemeController flips the mode and triggers a rebuild, every getter
  // returns the new value.

  static _Palette get _p => ThemeController.instance.isDark
      ? _DarkPalette.instance
      : _LightPalette.instance;

  // Surfaces
  static Color get scaffoldBg => _p.scaffoldBg;
  static Color get bottomNavBg => _p.bottomNavBg;
  static Color get stickyHeaderBg => _p.stickyHeaderBg;

  // Text on the (themed) page background
  static Color get textPrimary => _p.textPrimary;
  static Color get textBody => _p.textBody;
  static Color get textSecondary => _p.textSecondary;
  static Color get textMeta => _p.textMeta;
  static Color get textHint => _p.textHint;

  // Dividers, chevrons, subtle text on light surfaces
  static Color get divider => _p.divider;
  static Color get subtleText => _p.subtleText;
  static Color get chevronIcon => _p.chevronIcon;
  static Color get creditText => _p.creditText;

  // Offline banner (the orange tint reads differently on a dark scaffold)
  static Color get offlineBannerBg => _p.offlineBannerBg;

  // Now-playing green dot
  static Color get nowPlayingDot => _p.nowPlayingDot;
}

// ── Palette interface + implementations ─────────────────────────────────────

abstract class _Palette {
  Color get scaffoldBg;
  Color get bottomNavBg;
  Color get stickyHeaderBg;
  Color get textPrimary;
  Color get textBody;
  Color get textSecondary;
  Color get textMeta;
  Color get textHint;
  Color get divider;
  Color get subtleText;
  Color get chevronIcon;
  Color get creditText;
  Color get offlineBannerBg;
  Color get nowPlayingDot;
}

class _LightPalette implements _Palette {
  static final _LightPalette instance = _LightPalette._();
  _LightPalette._();

  @override
  final Color scaffoldBg = Colors.white;
  @override
  final Color bottomNavBg = const Color(0xFFF8FAFF);
  @override
  final Color stickyHeaderBg = Colors.white.withValues(alpha: 0.95);
  @override
  final Color textPrimary = Colors.black;
  @override
  final Color textBody = Colors.black87;
  @override
  final Color textSecondary = Colors.black54;
  @override
  final Color textMeta = Colors.black45;
  @override
  final Color textHint = Colors.black26;
  @override
  final Color divider = Colors.black12;
  @override
  final Color subtleText = Colors.black54;
  @override
  final Color chevronIcon = Colors.black26;
  @override
  final Color creditText = const Color.fromARGB(204, 0, 0, 0);
  @override
  final Color offlineBannerBg = Colors.orange.shade100;
  @override
  final Color nowPlayingDot = Colors.greenAccent.shade400;
}

class _DarkPalette implements _Palette {
  static final _DarkPalette instance = _DarkPalette._();
  _DarkPalette._();

  // Near-black scaffold matches the dark watermark JPG (#0A121F).
  // Keeping these values in sync — if you regenerate the watermark
  // with a different bg, change this too.
  @override
  final Color scaffoldBg = const Color(0xFF0A121F);

  // Slightly lifted so the bottom nav reads as a subtle surface
  // separation rather than an extra shadow line.
  @override
  final Color bottomNavBg = const Color(0xFF131C2D);

  // Translucent so the watermark behind it is still hinted at
  @override
  final Color stickyHeaderBg = const Color(0xFF0A121F).withValues(alpha: 0.95);

  @override
  final Color textPrimary = Colors.white;
  @override
  final Color textBody = Colors.white.withValues(alpha: 0.92);
  @override
  final Color textSecondary = Colors.white70;
  @override
  final Color textMeta = Colors.white60;
  @override
  final Color textHint = Colors.white38;

  @override
  final Color divider = Colors.white12;
  @override
  final Color subtleText = Colors.white70;
  @override
  final Color chevronIcon = Colors.white38;
  // Used for the developer credit footer — stays visible on dark bg
  @override
  final Color creditText = const Color.fromARGB(204, 255, 255, 255);

  // Darker, less saturated orange wash so it doesn't glow on a black scaffold
  @override
  final Color offlineBannerBg = const Color(0xFF3A2410);

  // The green dot reads fine on dark — same accent
  @override
  final Color nowPlayingDot = Colors.greenAccent.shade400;
}
