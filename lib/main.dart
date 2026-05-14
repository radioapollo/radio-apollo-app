/* Main entry point

   App startup orchestrator: Firebase init, AppCheck activation,
   notifications, audio service, current-program service, sponsor
   blocklist, and finally MaterialApp under ServiceProvider.

   ─── Fast first frame ──────────────────────────────────────────────────────
   The splash stays on screen until Flutter renders its first frame. Any
   work `await`-ed in main() therefore extends the splash. On cold start
   from a push-notification tap — especially over LTE, where FCM/Firebase
   handshakes are slow — sequentially awaiting AppCheck activation, FCM
   topic reconciliation, the username re-claim, and a Firestore round-trip
   for "now playing" used to keep the user staring at the logo for several
   seconds before the app appeared. To users it looked like a hang.

   The fix is to keep main() lean: only the things the first frame
   genuinely depends on are awaited up front. Everything else is kicked
   off in the background and lets the UI render immediately.

   Critical (awaited before runApp):
     - WidgetsFlutterBinding
     - ThemeController.init() (avoids dark-mode flash)
     - Firebase.initializeApp() (everything else needs it)
     - UserService.init() (fast — SharedPreferences only; the slow
       re-claim is kicked off in the background by the service itself,
       so awaiting init() here costs maybe a millisecond but guarantees
       the chat screen knows the user's name on the first frame)
     - EulaService.init() / BlockService.init() (SharedPreferences only)
     - AudioService.init() (the foreground service host — the app's
       cold-start error screen depends on this succeeding)

   Deferred (kicked off after runApp via _initInBackground):
     - AppCheck activation
     - NotificationService.init() (subscriptions, cold-start tap)
     - Cast SDK init
     - ProfanityService.init()
     - CurrentProgramService.start() (first-fetch + 1-min poll)

   The home screen already shows cached "now playing" data via
   SharedPreferences, so the deferred CurrentProgramService.start()
   is invisible to the user. NotificationRouter is a ValueNotifier so
   a notification tap that arrives during init is picked up by
   ApolloNav as soon as both sides are ready, no ordering required.

   Web-safe Crashlytics
   ────────────────────
   Crashlytics doesn't ship for web, so every recordError /
   recordFlutterFatalError call is gated on `!kIsWeb`. The same guard
   wraps the one-time `setCrashlyticsCollectionEnabled` call.

   Sponsor blocklist wiring
   ────────────────────────
   The audio handler filters commercials out of the recently-played
   list by matching the artist position against known sponsor names.
   We subscribe to InfoService.sponsorsStream once here at startup and
   forward each emission to `audioHandler.updateSponsorNames(...)`.
   Subscription is cancelled in `_ApolloAppState.dispose()` alongside
   the existing program subscription.

   Theme controller
   ────────────────
   ThemeController.instance.init() is awaited before the first frame
   so the persisted Light/Dark choice is applied immediately — no
   white flash on cold start for users in dark mode. The controller
   is then wired into the widget tree via AnimatedBuilder around
   MaterialApp; toggling the mode rebuilds the entire app, which
   re-reads every AppColors getter and swaps the watermark asset.

   Watermark continuity
   ────────────────────
   Both watermark variants are kept mounted at all times by
   ThemedWatermarkBackground (see widgets/themed_watermark_background.dart).
   That widget stacks both images and toggles their opacity, so flipping
   the theme doesn't show a frame of bare scaffold while a JPG decodes.
*/

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:audio_service/audio_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'navigation/apollo_nav.dart';
import 'services/audio_handler.dart';
import 'services/info_service.dart';
import 'services/program/current_program_service.dart';
import 'services/chat/user_service.dart';
import 'services/chat/block_service.dart';
import 'services/theme/theme_controller.dart';
import 'utils/profanity/profanity_service.dart';
import 'services/notifications/notification_service.dart';
import 'services/notifications/notification_router.dart';
import 'widgets/service_provider.dart';
import 'firebase_options.dart';
import 'constants/constants.dart';
import 'theme/app_theme.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'services/chat/eula_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Load the persisted theme preference before the first frame so we
  // don't flash light-mode UI for dark-mode users on cold start.
  await ThemeController.instance.init();

  // ── Critical: Firebase ────────────────────────────────────────────────────
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('[main] Firebase init failed: $e');
    runApp(
      const _ErrorApp(message: 'Kan Firebase niet laden. Herstart de app.'),
    );
    return;
  }

  // The background FCM handler must be registered before any message can
  // arrive, so do it on the same isolate as Firebase init.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Cold-start tap routing. If the user launched the app by tapping a
  // notification, FCM has buffered that message and getInitialMessage()
  // returns it. We resolve it into a target tab now and push it into
  // NotificationRouter, so ApolloNav's initState() can use it as the
  // PageView's initialPage. Without this, the user briefly lands on
  // Home and is then animated to Chat — which is correct but jarring.
  //
  // getInitialMessage() is a single platform-channel call; it doesn't
  // make a network request, so it's fast enough to keep on the
  // critical path. The wider NotificationService.init() (subscription
  // reconciliation, permission probe) stays in _initInBackground.
  try {
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      final category = initialMessage.data['category'] as String?;
      NotificationRouter.instance.setRequestedTabForCategory(category);
    }
  } catch (e) {
    debugPrint('[main] getInitialMessage failed: $e');
  }

  if (!kIsWeb) {
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
      !kDebugMode,
    );
  }

  _installErrorHandlers();

  // ── Fast local-only inits ────────────────────────────────────────────────
  //
  // These are all SharedPreferences-backed and complete in single-digit
  // milliseconds. They MUST run before runApp() because the first frame
  // reads from them — UserService.hasUsername drives the chat screen's
  // "Kies een naam" prompt, EulaService.hasAccepted gates message
  // sending, BlockService.isBlocked filters the message list.
  //
  // UserService.init() does its slow Firestore + Cloud Function
  // verification in the background — see user_service.dart. So awaiting
  // it here costs a SharedPreferences read, not a network round-trip.
  await _initUser();

  try {
    await EulaService.instance.init();
  } catch (e, st) {
    debugPrint('[main] EulaService init failed: $e');
    _recordError(e, st, reason: 'EulaService.init');
  }

  try {
    await BlockService.instance.init();
  } catch (e, st) {
    debugPrint('[main] BlockService init failed: $e');
    _recordError(e, st, reason: 'BlockService.init');
  }

  // ── Critical: AudioService (the foreground service host) ─────────────────
  late final RadioAudioHandler audioHandler;
  try {
    audioHandler = await AudioService.init(
      builder: () => RadioAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: AppConstants.notificationChannelId,
        androidNotificationChannelName: AppConstants.notificationChannelName,
        androidNotificationOngoing: true,
      ),
    );
  } catch (e, st) {
    debugPrint('[main] AudioService init failed: $e');
    _recordError(e, st, reason: 'AudioService.init (fatal)', fatal: true);
    runApp(
      const _ErrorApp(
        message: 'Audiodienst kon niet starten. Herstart de app.',
      ),
    );
    return;
  }

  // ── Run the app immediately ──────────────────────────────────────────────
  //
  // Everything below this point runs in the background while the first
  // frame is already on screen. The home screen shows cached "now
  // playing" data, the chat screen waits patiently for the username
  // re-claim, and NotificationRouter's ValueNotifier means a cold-start
  // tap that arrives while we're still initialising is picked up by
  // ApolloNav as soon as it attaches its listener.

  final currentProgramService = CurrentProgramService();

  // Seed the home screen's player card with the last-known program from
  // SharedPreferences. Without this, the first frame would show the
  // generic "Radio Apollo" / "Luister live" placeholder instead of the
  // actual program name. This is local-only, so it's cheap on the
  // critical path. The live Firestore fetch is still deferred into
  // _initInBackground via currentProgramService.start().
  try {
    await currentProgramService.loadCachedProgram();
  } catch (e, st) {
    debugPrint('[main] loadCachedProgram failed: $e');
    _recordError(e, st, reason: 'CurrentProgramService.loadCachedProgram');
  }

  late StreamSubscription programSub;
  late StreamSubscription sponsorSub;

  programSub = currentProgramService.currentProgram.listen((program) {
    audioHandler.setCurrentProgram(
      program.title ?? '',
      imageUrl: program.imageUrl,
    );
  });

  // Seed the audio handler with whatever was just loaded from cache,
  // since the listener above only fires on FUTURE emissions and the
  // cached emission already happened inside loadCachedProgram().
  final seededProgram = currentProgramService.lastProgram;
  if (seededProgram.hasData) {
    audioHandler.setCurrentProgram(
      seededProgram.title ?? '',
      imageUrl: seededProgram.imageUrl,
    );
  }

  // Seed the audio handler with whatever sponsors InfoService already
  // has cached (typically empty on cold start, populated on warm start).
  final cachedSponsors = InfoService.instance.latestSponsors;
  if (cachedSponsors != null) {
    audioHandler.updateSponsorNames(
      cachedSponsors.map((s) => s.title).toList(),
    );
  }

  // Forward every sponsor-list change to the audio handler.
  sponsorSub = InfoService.instance.sponsorsStream.listen((sponsors) {
    audioHandler.updateSponsorNames(sponsors.map((s) => s.title).toList());
  });

  runApp(
    ApolloApp(
      audioHandler: audioHandler,
      currentProgramService: currentProgramService,
      programSubscription: programSub,
      sponsorSubscription: sponsorSub,
    ),
  );

  // Fire-and-forget background init. Each step is independently
  // protected so a slow or failing one doesn't block the others.
  unawaited(_initInBackground(currentProgramService));
}

// ── Background init ─────────────────────────────────────────────────────────

Future<void> _initInBackground(CurrentProgramService currentProgramService) async {
  // Local notification channels must exist before any notification can
  // render. The background message handler also calls ensureChannels,
  // but doing it once here on the main isolate keeps cold-start
  // foreground messages reliable too.
  try {
    final tempPlugin = FlutterLocalNotificationsPlugin();
    await tempPlugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    await ensureNotificationChannels(tempPlugin);
  } catch (e, st) {
    debugPrint('[main] Local notifications init failed: $e');
    _recordError(e, st, reason: 'LocalNotifications.init');
  }

  await _activateAppCheck();

  // NotificationService.init() handles the cold-start tap. It pushes
  // the result into NotificationRouter, which ApolloNav listens to
  // — so the routing happens as soon as both sides are ready, no
  // ordering required.
  try {
    await NotificationService.instance.init();
  } catch (e, st) {
    debugPrint('[main] NotificationService init failed: $e');
    _recordError(e, st, reason: 'NotificationService.init');
  }

  if (!kIsWeb) await _initCast();

  try {
    await ProfanityService.instance.init();
  } catch (e, st) {
    debugPrint('[main] ProfanityService init failed: $e');
    _recordError(e, st, reason: 'ProfanityService.init');
  }

  try {
    await currentProgramService.start();
  } catch (e, st) {
    debugPrint('[main] CurrentProgramService start failed: $e');
    _recordError(e, st, reason: 'CurrentProgramService.start');
  }
}

// ── Crashlytics helpers (web-safe) ──────────────────────────────────────────

void _recordError(
  Object e,
  StackTrace st, {
  String? reason,
  bool fatal = false,
}) {
  if (kIsWeb) return;
  FirebaseCrashlytics.instance.recordError(e, st, reason: reason, fatal: fatal);
}

void _recordFlutterFatalError(FlutterErrorDetails details) {
  if (kIsWeb) return;
  FirebaseCrashlytics.instance.recordFlutterFatalError(details);
}

// ── Startup helpers ─────────────────────────────────────────────────────────

void _installErrorHandlers() {
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('[FlutterError] ${details.exceptionAsString()}');
    _recordFlutterFatalError(details);
  };
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('[UncaughtError] $error\n$stack');
    _recordError(error, stack, fatal: true);
    return true;
  };
}

Future<void> _activateAppCheck() async {
  try {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
      providerApple: kDebugMode
          ? const AppleDebugProvider()
          : const AppleDeviceCheckProvider(),
    );
  } catch (e, st) {
    debugPrint('[main] App Check activation failed: $e');
    _recordError(e, st, reason: 'AppCheck.activate');
  }
}

Future<void> _initCast() async {
  try {
    const appId = GoogleCastDiscoveryCriteria.kDefaultApplicationId;
    GoogleCastOptions? castOptions;

    if (Platform.isIOS) {
      castOptions = IOSGoogleCastOptions(
        GoogleCastDiscoveryCriteriaInitialize.initWithApplicationID(appId),
      );
    } else if (Platform.isAndroid) {
      castOptions = GoogleCastOptionsAndroid(appId: appId);
    }

    if (castOptions != null) {
      GoogleCastContext.instance.setSharedInstanceWithOptions(castOptions);
      try {
        GoogleCastDiscoveryManager.instance.startDiscovery();
      } catch (e, st) {
        debugPrint('[main] Cast discovery start failed: $e');
        _recordError(e, st, reason: 'Cast discovery start');
      }
    }
  } catch (e, st) {
    debugPrint('[main] Cast init failed: $e');
    _recordError(e, st, reason: 'Cast init');
  }
}

Future<void> _initUser() async {
  try {
    await UserService.instance.init();
  } catch (e, st) {
    debugPrint('[main] UserService init failed: $e');
    _recordError(e, st, reason: 'UserService.init');
  }
}

// ── Fallback error screen ───────────────────────────────────────────────────

class _ErrorApp extends StatelessWidget {
  final String message;
  const _ErrorApp({required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.black87),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Main app widget ─────────────────────────────────────────────────────────

class ApolloApp extends StatefulWidget {
  final RadioAudioHandler audioHandler;
  final CurrentProgramService currentProgramService;
  final StreamSubscription programSubscription;
  final StreamSubscription sponsorSubscription;

  const ApolloApp({
    super.key,
    required this.audioHandler,
    required this.currentProgramService,
    required this.programSubscription,
    required this.sponsorSubscription,
  });

  @override
  State<ApolloApp> createState() => _ApolloAppState();
}

class _ApolloAppState extends State<ApolloApp> {
  @override
  void dispose() {
    widget.programSubscription.cancel();
    widget.sponsorSubscription.cancel();
    widget.currentProgramService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (context, _) {
        final isDark = ThemeController.instance.isDark;
        return ServiceProvider(
          audioHandler: widget.audioHandler,
          currentProgramService: widget.currentProgramService,
          child: MaterialApp(
            title: 'Radio Apollo',
            theme: ThemeData(
              fontFamily: 'Sans',
              scaffoldBackgroundColor: AppColors.scaffoldBg,
              colorScheme: ColorScheme.fromSeed(
                seedColor: AppColors.primary,
                brightness: isDark ? Brightness.dark : Brightness.light,
              ),
              useMaterial3: true,
            ),
            builder: (context, child) {
              // KeyedSubtree forces the entire screen subtree to rebuild
              // when the theme flips, so every screen re-reads AppColors
              // immediately — no need to navigate away to see the change.
              return KeyedSubtree(key: ValueKey(isDark), child: child!);
            },
            home: const ApolloNav(),
          ),
        );
      },
    );
  }
}