/* Notification Service

   Manages push notification permissions, topic subscriptions, and the
   per-category preferences that drive them.

   Architecture
   ────────────
   We use FCM topics rather than per-device tokens. Each category the
   user can toggle in Settings maps to a single topic name (see
   NotificationCategory.topic). Subscribing/unsubscribing is the only
   identity the backend needs — no FCM tokens are stored in Firestore,
   which keeps the GDPR story simple (no personal device identifier
   leaves the device).

   Server-side, Cloud Functions publish to these topics:
   - studio_messages → on every new chat message with role == 'admin'
   - chat_activity   → optional, on regular user messages (off by default)
   - events          → from the daily event-reminder scheduled function
   - show_starting   → from the hourly schedule-check function

   Foreground display
   ──────────────────
   FCM does NOT auto-display notifications while the app is in the
   foreground — it only delivers them to onMessage. We use
   flutter_local_notifications to render them ourselves so the user
   sees a consistent banner regardless of app state.

   Persistence
   ───────────
   Per-category toggle state is stored in shared_preferences under
   keys of the form 'notif_<topic>'. Defaults are defined per-category
   on NotificationCategory. The OS-level permission is treated as a
   master switch: if the user has denied notifications system-wide,
   none of the in-app toggles do anything (the UI shows a banner that
   links to system settings).

   Why a singleton
   ───────────────
   Mirrors UserService and AuthService — one instance, initialised in
   main() before the first frame, accessed via NotificationService.instance.
*/

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_category.dart';

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

  /// Last known OS-level permission status. Read this from the UI to
  /// decide whether to show the "notifications are off in your phone
  /// settings" banner.
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
  ///
  /// - `none`        : everything's fine, no banner.
  /// - `notYetAsked` : OS hasn't been asked yet (or the user dismissed
  ///                   the prompt). Banner offers a button that
  ///                   triggers the prompt directly.
  /// - `denied`      : we asked and got refused, OR the user turned
  ///                   notifications off in system settings. The OS
  ///                   prompt usually won't reappear in this state,
  ///                   so the banner button takes the user to system
  ///                   settings instead.
  PermissionBannerState get bannerState {
    if (isAuthorized) return PermissionBannerState.none;
    if (_hasAskedForPermission) return PermissionBannerState.denied;
    return PermissionBannerState.notYetAsked;
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  /// Called once from main(). Sets up the local-notifications plugin,
  /// reads the current OS permission, and (if authorised) reconciles
  /// the saved category preferences with FCM topic subscriptions.
  ///
  /// Does NOT prompt the user for permission — that's done later, on
  /// first interaction with the Settings screen, so the prompt has
  /// context. See requestPermission().
  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;

    await _initLocalPlugin();
    await _refreshAuthStatus();

    // Read the persisted "has asked" flag — this is the only reliable
    // way to distinguish "never been asked" from "denied" on Android.
    final prefs = await SharedPreferences.getInstance();
    _hasAskedForPermission = prefs.getBool(_hasAskedKey) ?? false;

    // If the user already granted permission in a previous session,
    // make sure FCM topic subscriptions match the saved toggle state.
    if (isAuthorized) {
      await _reconcileSubscriptions();
    }

    _wireMessageHandlers();
  }

  Future<void> _initLocalPlugin() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      // We request permissions explicitly via firebase_messaging instead;
      // these flags only control whether the local plugin requests them
      // again on init, which would be redundant.
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _local.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    // Channel creation lives in a top-level function (see
    // ensureNotificationChannels) so it can also run from main.dart
    // before Firebase init, and from the FCM background isolate which
    // has its own Dart engine that doesn't share state with this
    // service instance.
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

    // Background / terminated: handled by the top-level handler in main.dart.
    // Tap-to-open from a terminated state is also routed there via
    // FirebaseMessaging.instance.getInitialMessage().
  }

  Future<void> _displayForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    // Pick the channel based on the topic the message came in on.
    // Server includes 'category' in message.data so we don't have to
    // parse the topic from the 'from' field (which is "/topics/<name>").
    final categoryKey = message.data['category'] as String?;
    final category = NotificationCategory.values.firstWhere(
      (c) => c.topic == categoryKey,
      orElse: () => NotificationCategory.studioMessages,
    );

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
          // below high importance, even if the channel itself is set
          // to high. We use `max` for guaranteed heads-up.
          importance: category.highImportance
              ? Importance.max
              : Importance.defaultImportance,
          priority: category.highImportance
              ? Priority.max
              : Priority.defaultPriority,
          // Hide the "8:59" timestamp that otherwise renders large in
          // the heads-up banner on stock Android. The body of a chat
          // message or event reminder is the content; the time it
          // arrived isn't useful and just visually competes.
          showWhen: false,
          // Stay in the shade until the user swipes it away. Without
          // this, the notification disappears the moment the heads-up
          // banner times out — there's nothing to scroll back to in
          // the shade. autoCancel keeps the "tap to dismiss" behaviour
          // so a tap on the banner still removes it.
          ongoing: false,
          autoCancel: true,
          // Tells Android this is a "message"-style notification,
          // which it uses to decide ranking and how to group entries
          // in the shade. Matches the studio chat use case better
          // than the default ('msg' equals AndroidNotificationCategory.message).
          category: AndroidNotificationCategory.message,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  // ── Permission ─────────────────────────────────────────────────────────────

  /// Prompt the user for OS-level notification permission. On Android
  /// 12 and below this is a no-op (auto-granted); on Android 13+ and
  /// iOS it shows the system dialog the first time, and is silently
  /// idempotent on subsequent calls.
  ///
  /// Returns true if the user granted permission. After a successful
  /// grant, any previously-saved category preferences are reconciled
  /// with FCM so the user immediately starts receiving the things
  /// they had toggled on.
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

    // Remember that we've asked, regardless of the outcome. This is
    // what lets us distinguish "fresh install" (no banner, just ask
    // on next toggle) from "denied" (show the banner).
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
  /// FCM topic subscription accordingly. Safe to call before the user
  /// has granted permission — the preference is saved either way, and
  /// the topic will be subscribed once permission lands via
  /// requestPermission() → _reconcileSubscriptions().
  Future<void> setEnabled(NotificationCategory category, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey(category), enabled);

    if (!isAuthorized) {
      // No permission yet — preference saved, but don't touch FCM. We
      // don't want to silently subscribe to topics the user can't
      // actually receive; reconcile happens after permission grant.
      return;
    }

    try {
      if (enabled) {
        await _fcm.subscribeToTopic(category.topic);
      } else {
        await _fcm.unsubscribeFromTopic(category.topic);
      }
    } catch (e) {
      // Topic (un)subscription is best-effort: it can fail offline or
      // if FCM is rate-limiting (3000 QPS per project — we won't hit
      // it, but the SDK can still throw). The preference is saved
      // locally, and _reconcileSubscriptions() runs again on next
      // app start, so a transient failure self-heals.
      debugPrint(
        '[NotificationService] subscribe/unsubscribe failed for '
        '${category.topic}: $e',
      );
    }
  }

  /// Re-applies all saved preferences to FCM. Called on startup (if
  /// already authorised) and right after a permission grant. This is
  /// what makes the toggle state durable across app reinstalls and
  /// transient network failures.
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

  /// We asked and were refused, OR the user turned notifications off in
  /// system settings later. Banner explains and offers a button to
  /// open system settings.
  denied,
}

/// Top-level channel creation. Idempotent: calling
/// `createNotificationChannel` multiple times with the same ID is a
/// no-op after the first call (Android's NotificationManager
/// deduplicates by ID).
///
/// Why top-level: the FCM background isolate that handles incoming
/// messages spins up its own Flutter engine, separate from the main
/// app's. State on the NotificationService singleton is invisible
/// from there. So we extract the channel-creation logic to a
/// stand-alone function that can be called from:
///   1. NotificationService.init() in the main app
///   2. main.dart before Firebase.initializeApp(), as belt-and-braces
///   3. firebaseMessagingBackgroundHandler() below
///
/// On most Android versions, FCM looks up the target channel
/// synchronously when displaying a notification — if the channel
/// doesn't exist, it falls back to the default channel (which is
/// low-importance, no heads-up). That's exactly the bug we hit:
/// the FCM service started before our service had created its
/// channels, so notifications got rendered at default importance.
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
        // Once a channel is created on Android with a given
        // importance, the user can lower it via system settings,
        // but the app cannot raise it without uninstalling. So pick
        // wisely on the first install.
        //
        // We use `max` for high-importance categories because it
        // is the level that explicitly guarantees a heads-up
        // banner across Android skins. `high` is supposed to do
        // the same but is unreliable on some emulators and OEMs.
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

/// Top-level background message handler. Must be a top-level or static
/// function annotated with @pragma('vm:entry-point') so the Flutter
/// engine can find it from the background isolate.
///
/// Even though FCM is the one rendering background notifications (not
/// us), we still ensure channels exist here so the very first message
/// after install/restart finds the high-importance channel ready. If
/// the channel doesn't exist when FCM tries to look it up by the ID
/// from AndroidManifest.xml, FCM silently falls back to a default
/// channel — which is exactly the heads-up banner bug.
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