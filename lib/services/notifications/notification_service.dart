/* Notification Service

   Manages push notification permissions, topic subscriptions, the
   per-category preferences that drive them, and tap-to-route.

   Architecture
   ────────────
   We use FCM topics rather than per-device tokens. Each category the
   user can toggle in Settings maps to a single topic name (see
   NotificationCategory.topic). Subscribing/unsubscribing is the only
   identity the backend needs — no FCM tokens are stored in Firestore,
   which keeps the GDPR story simple.

   Server-side, Cloud Functions publish to these topics:
   - studio_messages → on every new chat message with role == 'admin'
   - chat_activity   → optional, on regular user messages (off by default)
   - events          → from the daily scheduled job in functions/notifications.js

   Foreground display
   ──────────────────
   FCM does NOT auto-display notifications while the app is in the
   foreground — it only delivers them to onMessage. We use
   flutter_local_notifications to render them ourselves so the user
   sees a consistent banner regardless of app state.

   Self-notification suppression
   ─────────────────────────────
   When the user sends a chat message themselves, the FCM message
   from chat_activity arrives back at their own device. We don't
   want to notify them about their own send. The Cloud Function
   includes the sender's username in `data.sender`; if that matches
   UserService.instance.username we drop the foreground notification.

   Background/terminated self-suppression is harder because FCM
   renders those itself without giving us a hook. In practice this
   is rare: the user is on the chat screen (foreground) when sending,
   and any chat_activity notification arriving while they're elsewhere
   is from someone else. If this becomes a real complaint we'd switch
   chat_activity to data-only messages and render in all states
   ourselves; for now the foreground filter covers the actual use case.

   Tap-to-route
   ────────────
   Three message-arrival paths can end with a tap:
   - Cold start (app terminated)        → getInitialMessage() in init()
   - Background → user taps             → onMessageOpenedApp stream
   - Foreground → local plugin renders  → onDidReceiveNotificationResponse
   All three feed NotificationRouter.setRequestedTabForCategory(),
   which ApolloNav listens to.

   Persistence
   ───────────
   Per-category toggle state is stored in shared_preferences under
   keys of the form 'notif_<topic>'. Defaults are defined per-category
   on NotificationCategory.

   Permission tracking on Android
   ──────────────────────────────
   On Android 13+, getNotificationSettings() returns `denied` for both
   "never asked" and "actually denied" — there's no way to tell them
   apart at the OS level. So we track _hasAskedForPermission ourselves
   in shared_preferences. See PermissionBannerState below.
*/

import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../chat/user_service.dart';
import 'notification_category.dart';
import 'notification_router.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  bool _initialised = false;
  AuthorizationStatus _authStatus = AuthorizationStatus.notDetermined;
  bool _hasAskedForPermission = false;

  /// Key in shared_preferences. Tracks whether we've ever called
  /// requestPermission(). Needed because on Android 13+,
  /// getNotificationSettings() returns `denied` both for a fresh
  /// install AND for a real denial — there's no way to tell them
  /// apart from the OS, so we have to remember it ourselves.
  static const _hasAskedKey = 'notif_has_asked';

  /// Last known OS-level permission status.
  AuthorizationStatus get authorizationStatus => _authStatus;

  /// Whether requestPermission() has ever been called (in this install).
  /// True after the first prompt, regardless of what the user chose.
  bool get hasAskedForPermission => _hasAskedForPermission;

  /// True when the user has granted (or provisionally granted) OS-level
  /// permission to show notifications.
  bool get isAuthorized =>
      _authStatus == AuthorizationStatus.authorized ||
      _authStatus == AuthorizationStatus.provisional;

  /// Banner state used by the Settings screen to explain why
  /// notifications won't arrive, if anything is wrong.
  PermissionBannerState get bannerState {
    if (isAuthorized) return PermissionBannerState.none;
    if (_hasAskedForPermission) return PermissionBannerState.denied;
    return PermissionBannerState.notYetAsked;
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;

    await _initLocalPlugin();
    await _refreshAuthStatus();

    final prefs = await SharedPreferences.getInstance();
    _hasAskedForPermission = prefs.getBool(_hasAskedKey) ?? false;

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
    final settings = await _fcm.getNotificationSettings();
    _authStatus = settings.authorizationStatus;
  }

  /// Re-reads the OS permission status. Call this when the Settings
  /// screen reopens — the user may have toggled notifications in
  /// system settings while away, and we want the banner to reflect
  /// reality on return.
  Future<void> refresh() async {
    await _refreshAuthStatus();
  }

  void _wireMessageHandlers() {
    FirebaseMessaging.onMessage.listen(_displayForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);
  }

  Future<void> _handleColdStartTap() async {
    final message = await _fcm.getInitialMessage();
    if (message == null) return;
    _routeFromMessage(message);
  }

  void _onMessageOpenedApp(RemoteMessage message) {
    _routeFromMessage(message);
  }

  void _routeFromMessage(RemoteMessage message) {
    final category = message.data['category'] as String?;
    NotificationRouter.instance.setRequestedTabForCategory(category);
  }

  // ── Foreground display ────────────────────────────────────────────────────

  Future<void> _displayForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    // Drop chat_activity notifications for messages the user sent
    // themselves. The Cloud Function includes the sender's username in
    // data.sender; we compare it (case-insensitively to match Firestore
    // doc IDs) with the locally claimed name. If it matches, return
    // without rendering.
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
          priority: category.highImportance
              ? Priority.max
              : Priority.defaultPriority,
          showWhen: false,
          ongoing: false,
          autoCancel: true,
          category: AndroidNotificationCategory.message,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: payload,
    );
  }

  /// Returns true when the FCM data identifies the local user as the
  /// sender, so we should drop the notification. Currently only fires
  /// for chat_activity messages; other categories don't include
  /// `sender` so the check no-ops harmlessly.
  bool _isOwnMessage(Map<String, dynamic> data) {
    final sender = (data['sender'] as String?)?.trim().toLowerCase();
    if (sender == null || sender.isEmpty) return false;

    final localName = UserService.instance.username?.trim().toLowerCase();
    if (localName == null || localName.isEmpty) return false;

    return sender == localName;
  }

  void _onLocalNotificationTapped(NotificationResponse response) {
    final raw = response.payload;
    if (raw == null || raw.isEmpty) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final category = data['category'] as String?;
      NotificationRouter.instance.setRequestedTabForCategory(category);
    } catch (e) {
      debugPrint('[NotificationService] Failed to decode tap payload: $e');
    }
  }

  // ── Permission ─────────────────────────────────────────────────────────────

  Future<bool> requestPermission() async {
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    _authStatus = settings.authorizationStatus;

    _hasAskedForPermission = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasAskedKey, true);

    if (isAuthorized) {
      await _reconcileSubscriptions();
    }
    return isAuthorized;
  }

  // ── Category preferences ──────────────────────────────────────────────────

  Future<bool> isEnabled(NotificationCategory category) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsKey(category)) ?? category.defaultEnabled;
  }

  Future<void> setEnabled(NotificationCategory category, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey(category), enabled);

    if (!isAuthorized) return;

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
          '[NotificationService] reconcile failed for '
          '${category.topic}: $e',
        );
      }
    }
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  String _prefsKey(NotificationCategory category) => 'notif_${category.topic}';
}

/// What banner (if any) the Settings screen should display about the
/// OS-level notification permission.
enum PermissionBannerState {
  none,
  notYetAsked,
  denied,
}

/// Top-level channel creation. Idempotent.
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

/// Top-level background message handler. Must be a top-level or
/// static function annotated with @pragma('vm:entry-point') so the
/// Flutter engine can find it from the background isolate.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
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