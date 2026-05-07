/* Theme Controller

   Tracks the user's preferred app theme (light or dark) and persists
   the choice to SharedPreferences so it survives app restarts.

   Same pattern as EulaService and BlockService: a singleton
   ChangeNotifier with a one-shot init(), exposed to the UI via
   AnimatedBuilder higher up in the widget tree.

   The actual color swapping happens in app_colors.dart, which reads
   `ThemeController.instance.isDark` from its static getters. When the
   user toggles the theme, this controller calls notifyListeners() and
   the AnimatedBuilder wrapping MaterialApp rebuilds the entire tree.

   We deliberately don't expose a "system" mode — the user asked for a
   manual switch, and "follow system" can always be added later by
   widening AppThemeMode and reading
   MediaQuery.platformBrightnessOf(context) when the mode is system.

   First-launch default: light. The original app shipped light-only,
   so existing users see exactly what they had before until they
   actively flip the switch.
*/

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode { light, dark }

class ThemeController extends ChangeNotifier {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  static const _prefsKey = 'app_theme_mode';

  AppThemeMode _mode = AppThemeMode.light;
  bool _initialised = false;

  AppThemeMode get mode => _mode;
  bool get isDark => _mode == AppThemeMode.dark;
  bool get isInitialised => _initialised;

  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_prefsKey);
      if (stored == AppThemeMode.dark.name) {
        _mode = AppThemeMode.dark;
      } else {
        _mode = AppThemeMode.light;
      }
    } catch (e) {
      debugPrint('[ThemeController] Failed to load preference: $e');
      _mode = AppThemeMode.light;
    }
  }

  Future<void> setMode(AppThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, mode.name);
    } catch (e) {
      debugPrint('[ThemeController] Failed to persist preference: $e');
    }
  }

  Future<void> toggle() async {
    await setMode(isDark ? AppThemeMode.light : AppThemeMode.dark);
  }
}
