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

  /// Called once from main(). Sets up the local-notifications plugin,
  /// reads the current OS permission, reconciles category preferences
  /// with FCM topic subscriptions if already authorised, wires the
  /// foreground/background message handlers, and checks for a
  /// pending tap-to-route from a cold start.
  ///
  /// Does NOT prompt the user for permission — that's done later on
  /// first interaction with the Settings screen.
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
      // Foreground tap path: when our local plugin rendered the banner
      // and the user tapped it, this fires. The payload carries the
      // `data` map from the original FCM message, JSON-encoded.
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
    // Foreground: render with the local plugin so the user sees a banner.
    FirebaseMessaging.onMessage.listen(_displayForegroundMessage);

    // Background tap: user tapped a notification while the app was
    // backgrounded. The system brings the app to the foreground and
    // fires this stream with the message payload.
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);
  }

  /// Cold-start tap: app was terminated, user tapped a notification.
  /// Android/iOS launches the app and we can read which message
  /// caused it via getInitialMessage(). Returns null when the app was
  /// launched normally (icon tap, fresh install, etc.).
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

    final categoryKey = message.data['category'] as String?;
    final category = NotificationCategory.values.firstWhere(
      (c) => c.topic == categoryKey,
      orElse: () => NotificationCategory.studioMessages,
    );

    // Encode the data map as the local notification's payload so the
    // tap callback can read it. JSON because payload is a single
    // String and we need to round-trip a Map<String, String>.
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
          // Match the channel's importance — Android won't show a
          // heads-up banner over a foreground app for a notification
          // below high importance. We use `max` for guaranteed heads-up.
          importance: category.highImportance
              ? Importance.max
              : Importance.defaultImportance,
          priority: category.highImportance
              ? Priority.max
              : Priority.defaultPriority,
          // Hide the timestamp that otherwise renders large in the
          // heads-up banner on stock Android.
          showWhen: false,
          // Stay in the shade until the user swipes or taps.
          ongoing: false,
          autoCancel: true,
          // Lets Android rank and group this as a message-style
          // notification rather than generic. Better UX in the shade.
          category: AndroidNotificationCategory.message,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: payload,
    );
  }

  /// Called by the local plugin when the user taps a notification we
  /// rendered ourselves (foreground path).
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

  /// Prompt the user for OS-level notification permission. On Android
  /// 12 and below this is a no-op (auto-granted); on Android 13+ and
  /// iOS it shows the system dialog the first time and is silently
  /// idempotent on subsequent calls.
  ///
  /// Always sets `hasAskedForPermission` to true — needed because on
  /// Android the OS doesn't track this for us.
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

  /// Whether the user has enabled this category. Defaults to the
  /// category's `defaultEnabled` value if no preference is saved yet.
  Future<bool> isEnabled(NotificationCategory category) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsKey(category)) ?? category.defaultEnabled;
  }

  /// Toggle a category on or off. Persists the choice and updates the
  /// FCM topic subscription. Safe to call before the user has granted
  /// permission — the preference is saved either way and the topic
  /// will be subscribed once permission lands via reconcile.
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
      // Best-effort: a transient FCM failure is recovered on next
      // app start by _reconcileSubscriptions().
      debugPrint(
        '[NotificationService] subscribe/unsubscribe failed for '
        '${category.topic}: $e',
      );
    }
  }

  /// Re-applies all saved preferences to FCM. Called on startup (if
  /// already authorised) and right after a permission grant.
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
  /// No banner — everything's working.
  none,

  /// We have not yet successfully asked for permission. Banner explains
  /// notifications are off and offers a button to ask now.
  notYetAsked,

  /// We asked and were refused, OR the user turned notifications off
  /// in system settings later. Banner explains and offers a button to
  /// open system settings.
  denied,
}

/// Top-level channel creation. Idempotent: createNotificationChannel
/// with the same ID is a no-op after the first call.
///
/// Why top-level: the FCM background isolate that handles incoming
/// messages spins up its own Flutter engine, separate from the main
/// app's. State on the NotificationService singleton is invisible
/// from there. So channel creation lives here and gets called from:
///   1. NotificationService.init() in the main app
///   2. main.dart before Firebase.initializeApp() (belt-and-braces)
///   3. firebaseMessagingBackgroundHandler() below
///
/// On most Android versions, FCM looks up the target channel
/// synchronously when displaying a notification — if the channel
/// doesn't exist, it falls back to the default channel (which is
/// low-importance, no heads-up). Calling this everywhere prevents
/// that race.
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
        // Once a channel is created with a given importance, the user
        // can lower it via system settings, but the app cannot raise
        // it without uninstalling. So pick wisely on the first
        // install. We use `max` for high-importance categories
        // because it explicitly guarantees a heads-up banner across
        // Android skins.
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
///
/// Even though FCM is the one rendering background notifications (not
/// us), we still ensure channels exist here so the very first message
/// after install/restart finds the high-importance channel ready.
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