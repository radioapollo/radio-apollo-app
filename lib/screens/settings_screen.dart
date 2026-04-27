/* Settings Screen

   User-facing settings for the app. Currently contains only the
   notification preferences, but is structured to grow — add a new
   section in _buildContent() and that's it.

   Notification UX
   ───────────────
   We model OS-level permission as one of three banner states (see
   PermissionBannerState in notification_service.dart):

   - none          : permission is granted. No banner, just toggles.
   - notYetAsked   : we've never gotten permission. Banner offers a
                     button that triggers the OS prompt directly.
   - denied        : permission was refused or turned off in system
                     settings. Banner button opens system settings,
                     since the OS prompt won't reappear.

   On top of the banner, toggling a switch ON when permission isn't
   granted *also* triggers the prompt. That way the user has two
   paths to grant permission: the banner if they read top-down, or
   the switch if they jump straight to the category they want.

   AppLifecycleState observer
   ──────────────────────────
   The user might pop into Android Settings and flip notifications
   on (or off) while the screen is showing. We listen to the app
   lifecycle so when they return, we re-read the permission status
   and rebuild the banner accordingly.

   Reachable from the gear icon on the Info screen header.
*/

import 'package:flutter/material.dart';

import '../services/notifications/notification_service.dart';
import '../services/notifications/notification_category.dart';
import '../theme/app_theme.dart';
import '../constants/constants.dart';
import '../widgets/settings/notification_permission_banner.dart';
import '../widgets/settings/notification_toggle_tile.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  final _service = NotificationService.instance;

  /// Cached state per category so toggle taps are instant. Repopulated
  /// from the service on initState and after every change.
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
    // When the user comes back from Android system settings, re-read
    // the permission state so the banner can update.
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

  /// Triggered from the banner button in the `notYetAsked` state, and
  /// also internally from `_onToggle` when the user flips a switch on
  /// without permission yet granted.
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
    // Optimistic update so the switch animates immediately. If we end
    // up needing to roll back (permission denied at the OS prompt),
    // we'll flip it again in the rollback path below.
    setState(() => _enabled[category] = value);

    // Turning a switch ON is the moment to ensure we have permission.
    // requestPermission() is idempotent — if permission was already
    // granted, it returns immediately without showing a dialog.
    if (value && !_service.isAuthorized) {
      final granted = await _service.requestPermission();
      if (!mounted) return;

      setState(() => _bannerState = _service.bannerState);

      if (!granted) {
        // User declined the OS prompt (or was previously denied and
        // the OS won't ask again). Roll back the switch.
        setState(() => _enabled[category] = false);
        _showSnackBar(
          'Meldingen zijn geweigerd. Je kan ze later inschakelen via '
          'de telefooninstellingen.',
        );
        return;
      }
    }

    // Persist the (possibly post-permission) toggle state. The service
    // is a no-op on FCM subscriptions when permission isn't granted,
    // and reconciles itself once permission lands.
    await _service.setEnabled(category, value);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SizedBox.expand(
        child: Container(
          decoration: const BoxDecoration(
            image: AppDecorations.backgroundWatermark,
          ),
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
                icon: const Icon(
                  Icons.arrow_back,
                  color: AppColors.textPrimary,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: AppDimensions.spaceMedium),
              Image.asset(
                AppAssets.logo,
                height: AppDimensions.logoHeight,
                fit: BoxFit.contain,
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spaceMedium),
          const Text('Instellingen', style: AppTextStyles.screenTitle),
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
        const Text('Meldingen', style: AppTextStyles.screenTitleSmall),
        const SizedBox(height: AppDimensions.spaceLarge),

        // Banner shown only when the OS-level permission needs the
        // user's attention. See PermissionBannerState for the cases.
        NotificationPermissionBanner(
          state: _bannerState,
          onRequestPermission: _requestPermission,
        ),

        // Per-category toggles
        ...NotificationCategory.values.map((category) {
          return NotificationToggleTile(
            title: category.displayName,
            description: category.description,
            value: _enabled[category] ?? category.defaultEnabled,
            onChanged: (v) => _onToggle(category, v),
          );
        }),
      ],
    );
  }
}