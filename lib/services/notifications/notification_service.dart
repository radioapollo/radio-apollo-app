/* Notification Service

   Manages push notification permissions, topic subscriptions, the
   per-category preferences that drive them, and tap-to-route.

   Desktop safety
   ──────────────
   firebase_messaging (FCM) is only supported on Android, iOS, and Web.
   flutter_local_notifications is only supported on Android and iOS.
   Neither works on Windows, Linux, or macOS desktop.

   Every call to those packages is gated behind `_isMobile` so the
   service silently does nothing on desktop rather than crashing.
   Preference state (shared_preferences) still works everywhere, so
   nothing is lost if the same prefs file is read on another platform.
*/

import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_category.dart';
import 'notification_router.dart';
import '../chat/user_service.dart';

// True when running on Android or iOS (not web, not desktop).
bool get _isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

// ── Background handler ────────────────────────────────────────────────────
// Registered in main.dart only when _isMobile is true.

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (!_isMobile) return;
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    ),
  );
  await ensureNotificationChannels(plugin);
}

// ── Channel bootstrap helper ──────────────────────────────────────────────

Future<void> ensureNotificationChannels(
  FlutterLocalNotificationsPlugin plugin,
) async {
  final androidPlugin = plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  if (androidPlugin == null) return;

  for (final category in NotificationCategory.values) {
    await androidPlugin.createNotificationChannel(
      AndroidNotificationChannel(
        category.channelId,
        category.displayName,
        description: category.description,
        importance: category.highImportance
            ? Importance.max
            : Importance.defaultImportance,
      ),
    );
  }
  debugPrint(
    '[NotificationService] Ensured ${NotificationCategory.values.length} channels',
  );
}

// ── Permission banner state ───────────────────────────────────────────────

enum PermissionBannerState { none, notYetAsked, denied }

// ── Service ───────────────────────────────────────────────────────────────

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  AuthorizationStatus _authStatus = AuthorizationStatus.notDetermined;
  bool _hasAskedForPermission = false;

  bool get isAuthorized =>
      _authStatus == AuthorizationStatus.authorized ||
      _authStatus == AuthorizationStatus.provisional;

  // On desktop this always returns `none` so the Settings screen hides
  // the permission banner.
  PermissionBannerState get bannerState {
    if (!_isMobile) return PermissionBannerState.none;
    if (isAuthorized) return PermissionBannerState.none;
    if (!_hasAskedForPermission) return PermissionBannerState.notYetAsked;
    return PermissionBannerState.denied;
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> init() async {
    // Nothing to set up on desktop.
    if (!_isMobile) return;

    await _initLocalPlugin();

    final prefs = await SharedPreferences.getInstance();
    _hasAskedForPermission =
        prefs.getBool('notif_permission_asked') ?? false;

    await _refreshAuthStatus();

    if (isAuthorized) {
      await _reconcileSubscriptions();
    }

    _wireMessageHandlers();
    await _handleColdStartTap();
  }

  Future<void> _initLocalPlugin() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _local.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _onLocalNotificationTapped,
    );

    await ensureNotificationChannels(_local);
  }

  Future<void> _refreshAuthStatus() async {
    if (!_isMobile) return;
    final settings = await _fcm.getNotificationSettings();
    _authStatus = settings.authorizationStatus;
  }

  Future<void> refresh() async {
    await _refreshAuthStatus();
  }

  void _wireMessageHandlers() {
    if (!_isMobile) return;
    FirebaseMessaging.onMessage.listen(_displayForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);
  }

  Future<void> _handleColdStartTap() async {
    if (!_isMobile) return;
    final message = await _fcm.getInitialMessage();
    if (message == null) return;
    _routeFromMessage(message);
  }

  void _onMessageOpenedApp(RemoteMessage message) => _routeFromMessage(message);

  void _routeFromMessage(RemoteMessage message) {
    final category = message.data['category'] as String?;
    NotificationRouter.instance.setRequestedTabForCategory(category);
  }

  // ── Foreground display ────────────────────────────────────────────────────

  Future<void> _displayForegroundMessage(RemoteMessage message) async {
    if (!_isMobile) return;
    final notification = message.notification;
    if (notification == null) return;

    if (_isOwnMessage(message.data)) {
      debugPrint(
        '[NotificationService] Suppressing self-notification for '
        '${message.data['sender']}',
      );
      return;
    }

    final categoryKey = message.data['category'] as String?;
    final category = NotificationCategory.values.firstWhere(
      (c) => c.topic == categoryKey,
      orElse: () => NotificationCategory.studioMessages,
    );

    final payload = jsonEncode(message.data);

    await _local.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          category.channelId,
          category.displayName,
          channelDescription: category.description,
          importance: category.highImportance
              ? Importance.max
              : Importance.defaultImportance,
          priority:
              category.highImportance ? Priority.high : Priority.defaultPriority,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: payload,
    );
  }

  bool _isOwnMessage(Map<String, dynamic> data) {
    final sender = data['sender'] as String?;
    if (sender == null) return false;
    return sender == UserService.instance.username;
  }

  void _onLocalNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null) return;
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final category = data['category'] as String?;
      NotificationRouter.instance.setRequestedTabForCategory(category);
    } catch (_) {}
  }

  // ── Permission ────────────────────────────────────────────────────────────

  Future<bool> requestPermission() async {
    if (!_isMobile) return false;

    final prefs = await SharedPreferences.getInstance();
    _hasAskedForPermission = true;
    await prefs.setBool('notif_permission_asked', true);

    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    _authStatus = settings.authorizationStatus;
    return isAuthorized;
  }

  // ── Topic preferences ─────────────────────────────────────────────────────

  Future<bool> isEnabled(NotificationCategory category) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsKey(category)) ?? category.defaultEnabled;
  }

  Future<void> setEnabled(NotificationCategory category, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey(category), enabled);

    if (!_isMobile || !isAuthorized) return;

    try {
      if (enabled) {
        await _fcm.subscribeToTopic(category.topic);
      } else {
        await _fcm.unsubscribeFromTopic(category.topic);
      }
    } catch (e) {
      debugPrint(
        '[NotificationService] subscribe/unsubscribe failed for '
        '${category.topic}: $e',
      );
    }
  }

  Future<void> _reconcileSubscriptions() async {
    if (!_isMobile) return;
    for (final category in NotificationCategory.values) {
      final enabled = await isEnabled(category);
      try {
        if (enabled) {
          await _fcm.subscribeToTopic(category.topic);
        } else {
          await _fcm.unsubscribeFromTopic(category.topic);
        }
      } catch (e) {
        debugPrint(
          '[NotificationService] reconcile failed for ${category.topic}: $e',
        );
      }
    }
  }

  String _prefsKey(NotificationCategory category) => 'notif_${category.topic}';
}