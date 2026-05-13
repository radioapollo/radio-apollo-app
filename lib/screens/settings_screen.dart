/* Settings Screen

   User-facing settings for the app. Currently contains:
   - Weergave (Light/Dark theme) — top
   - Notification preferences  ← hidden on desktop (FCM not supported)
   - Chat preferences

   Desktop safety
   ──────────────
   The entire "Meldingen" section (permission banner + category toggles)
   is wrapped in `if (!_isDesktop)` so it simply doesn't render on
   Windows / Linux / macOS. FCM subscribe/unsubscribe would crash on
   those platforms and notifications don't apply there anyway.
*/

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/notifications/notification_service.dart';
import '../services/notifications/notification_category.dart';
import '../theme/app_theme.dart';
import '../constants/constants.dart';
import '../utils/url_launcher_utils.dart';
import '../widgets/settings/notification_permission_banner.dart';
import '../widgets/settings/notification_toggle_tile.dart';
import '../widgets/settings/theme_toggle_tile.dart';
import '../widgets/themed_watermark_background.dart';
import '../widgets/themed_logo.dart';
import 'blocked_users_screen.dart';

/// True when running on a desktop OS (Windows, Linux, macOS) — not mobile,
/// not web.
bool get _isDesktop =>
    !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  final _service = NotificationService.instance;

  final Map<NotificationCategory, bool> _enabled = {};

  bool _loading = true;
  PermissionBannerState _bannerState = PermissionBannerState.none;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshAuthStatus();
    }
  }

  // ── Data loading ──────────────────────────────────────────────────────────

  Future<void> _loadState() async {
    final entries = await Future.wait([
      for (final c in NotificationCategory.values) _service.isEnabled(c),
    ]);

    if (!mounted) return;
    setState(() {
      for (var i = 0; i < NotificationCategory.values.length; i++) {
        _enabled[NotificationCategory.values[i]] = entries[i];
      }
      _bannerState = _service.bannerState;
      _loading = false;
    });
  }

  Future<void> _refreshAuthStatus() async {
    await _service.refresh();
    if (!mounted) return;
    setState(() => _bannerState = _service.bannerState);
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _requestPermission() async {
    final granted = await _service.requestPermission();
    if (!mounted) return;
    setState(() => _bannerState = _service.bannerState);

    if (!granted) {
      _showSnackBar(
        'Meldingen zijn geweigerd. Je kan ze later inschakelen via '
        'de telefooninstellingen.',
      );
    }
  }

  Future<void> _onToggle(NotificationCategory category, bool value) async {
    setState(() => _enabled[category] = value);

    if (value && !_service.isAuthorized) {
      final granted = await _service.requestPermission();
      if (!mounted) return;

      setState(() => _bannerState = _service.bannerState);

      if (!granted) {
        setState(() => _enabled[category] = false);
        _showSnackBar(
          'Meldingen zijn geweigerd. Je kan ze later inschakelen via '
          'de telefooninstellingen.',
        );
        return;
      }
    }

    await _service.setEnabled(category, value);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 4)),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: ThemedWatermarkBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              Expanded(child: _buildContent()),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.paddingXLarge,
        AppDimensions.paddingXLarge,
        AppDimensions.paddingXLarge,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: AppDimensions.spaceMedium),
              const ThemedLogo(height: AppDimensions.logoHeight),
            ],
          ),
          const SizedBox(height: AppDimensions.spaceMedium),
          Text('Instellingen', style: AppTextStyles.screenTitle),
          const SizedBox(height: AppDimensions.spaceLarge),
        ],
      ),
    );
  }

  // ── Scrollable content ────────────────────────────────────────────────────

  Widget _buildContent() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.navyMedium),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.paddingXLarge,
        0,
        AppDimensions.paddingXLarge,
        AppDimensions.paddingXLarge,
      ),
      children: [
        // ── Weergave section ──────────────────────────────────────────────
        Text('Weergave', style: AppTextStyles.screenTitleSmall),
        const SizedBox(height: AppDimensions.spaceLarge),
        const ThemeToggleTile(),

        // ── Meldingen section (mobile only) ───────────────────────────────
        // FCM / local-notifications are not supported on desktop, so we
        // hide this entire section there.
        if (!_isDesktop) ...[
          const SizedBox(height: AppDimensions.spaceXLarge),
          Text('Meldingen', style: AppTextStyles.screenTitleSmall),
          const SizedBox(height: AppDimensions.spaceLarge),

          NotificationPermissionBanner(
            state: _bannerState,
            onRequestPermission: _requestPermission,
          ),

          ...NotificationCategory.values.map((category) {
            return NotificationToggleTile(
              title: category.displayName,
              description: category.description,
              value: _enabled[category] ?? category.defaultEnabled,
              onChanged: (v) => _onToggle(category, v),
            );
          }),
        ],

        // ── Chat section ──────────────────────────────────────────────────
        const SizedBox(height: AppDimensions.spaceXLarge),
        Text('Chat', style: AppTextStyles.screenTitleSmall),
        const SizedBox(height: AppDimensions.spaceLarge),

        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.block, color: AppColors.textPrimary),
          title: Text(
            'Geblokkeerde gebruikers',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            'Bekijk en deblokkeer gebruikers die je hebt geblokkeerd.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          trailing: Icon(Icons.chevron_right, color: AppColors.chevronIcon),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BlockedUsersScreen()),
            );
          },
        ),

        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            Icons.description_outlined,
            color: AppColors.textPrimary,
          ),
          title: Text(
            'Gebruiksvoorwaarden',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            'Lees de regels voor de chatfunctie.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          trailing: Icon(
            Icons.open_in_new,
            color: AppColors.chevronIcon,
            size: 18,
          ),
          onTap: () => UrlLauncherUtils.openUrl(AppConstants.termsOfUseUrl),
        ),
      ],
    );
  }
}