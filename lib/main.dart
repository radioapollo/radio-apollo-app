/* Main entry point

   App startup orchestrator: Firebase init, AppCheck activation,
   notifications, audio service, current-program service, sponsor
   blocklist, and finally MaterialApp under ServiceProvider.

   Desktop safety
   ──────────────
   Three mobile-only APIs now sit behind `_isMobile` guards so the app
   boots on Windows / Linux / macOS without crashing:

   1. FlutterLocalNotificationsPlugin + ensureNotificationChannels
      → mobile (Android / iOS) only.
   2. SystemChrome.setPreferredOrientations
      → mobile only; throws MissingPluginException on desktop.
   3. FirebaseAppCheck.activate with Android/Apple providers
      → no desktop providers exist; skip on Windows & Linux.
   4. _initCast (Chromecast SDK)
      → Android / iOS only; already gated on !kIsWeb but the inner
        Platform.isIOS check still throws on desktop — now returns
        early unless actually on a mobile OS.

   Web-safe Crashlytics
   ────────────────────
   Crashlytics doesn't ship for web, so every recordError /
   recordFlutterFatalError call is gated on `!kIsWeb`.
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
import 'widgets/service_provider.dart';
import 'firebase_options.dart';
import 'constants/constants.dart';
import 'theme/app_theme.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'services/chat/eula_service.dart';

/// True when running on Android or iOS (not web, not desktop).
bool get _isMobile =>
    !kIsWeb && (Platform.isAndroid || Platform.isIOS);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── DESKTOP CRASH LOGGER ────────────────────────────────────────────
  // Write any startup error to a file so we can read it after a crash.
  if (!_isMobile && !kIsWeb) {
    runZonedGuarded(
      _mainBody,
      (error, stack) {
        try {
          final logPath = '${Directory.systemTemp.path}\\radio_apollo_crash.txt';
          File(logPath).writeAsStringSync(
            'CRASH at ${DateTime.now()}\n\n$error\n\n$stack\n',
            mode: FileMode.append,
          );
          debugPrint('[CRASH] Logged to $logPath');
          debugPrint('[CRASH] $error\n$stack');
        } catch (_) {}
        runApp(
          _ErrorApp(message: 'Startup error: $error'),
        );
      },
    );
    return;
  }

  await _mainBody();
}

Future<void> _mainBody() async {
  // Mobile-only: create Android notification channels up front so that
  // the background isolate handler can reference them by ID.
  if (_isMobile) {
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
  }

  // Mobile-only: lock to portrait. Throws MissingPluginException on desktop.
  if (_isMobile) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  // Load the persisted theme preference before the first frame so we
  // don't flash light-mode UI for dark-mode users on cold start.
  await ThemeController.instance.init();

  bool firebaseReady = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 15));
    firebaseReady = true;
  } catch (e) {
    debugPrint('[main] Firebase init failed or timed out: $e');
    if (_isMobile) {
      runApp(
        const _ErrorApp(message: 'Kan Firebase niet laden. Herstart de app.'),
      );
      return;
    }
    // On desktop: continue without Firebase rather than blocking the app.
  }

  if (_isMobile) {
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
      !kDebugMode,
    );
  }

  _installErrorHandlers();

  // Background message handler only applies to mobile / web.
  if (_isMobile || kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  await _activateAppCheck();

  try {
    await NotificationService.instance.init();
  } catch (e, st) {
    debugPrint('[main] NotificationService init failed: $e');
    _recordError(e, st, reason: 'NotificationService.init');
  }

  if (!kIsWeb) await _initCast();

  await _initUser();

  try {
    await ProfanityService.instance.init().timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        debugPrint('[main] ProfanityService init timed out');
      },
    );
  } catch (e, st) {
    debugPrint('[main] ProfanityService init failed: $e');
    _recordError(e, st, reason: 'ProfanityService.init');
  }

  try {
    await BlockService.instance.init().timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        debugPrint('[main] BlockService init timed out');
      },
    );
  } catch (e, st) {
    debugPrint('[main] BlockService init failed: $e');
    _recordError(e, st, reason: 'BlockService.init');
  }

  try {
    await EulaService.instance.init().timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        debugPrint('[main] EulaService init timed out');
      },
    );
  } catch (e, st) {
    debugPrint('[main] EulaService init failed: $e');
    _recordError(e, st, reason: 'EulaService.init');
  }

  // ── Audio service (must succeed for the app to run) ───────────────────────
  // On desktop, audio_service has no implementation and would throw
  // MissingPluginException, so create the handler directly.

  late final RadioAudioHandler audioHandler;
  if (_isMobile || kIsWeb) {
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
  } else {
    // Desktop: skip AudioService background-service plumbing.
    audioHandler = RadioAudioHandler();
  }

  // ── Current program service ───────────────────────────────────────────────

  final currentProgramService = CurrentProgramService();
  try {
    await currentProgramService.start().timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        debugPrint('[main] CurrentProgramService start timed out');
      },
    );
  } catch (e, st) {
    debugPrint('[main] CurrentProgramService start failed: $e');
    _recordError(e, st, reason: 'CurrentProgramService.start');
  }

  final programSub = currentProgramService.currentProgram.listen((program) {
    audioHandler.setCurrentProgram(
      program.title ?? '',
      imageUrl: program.imageUrl,
    );
  });

  // ── Sponsor blocklist for commercial filtering ────────────────────────────

  final cachedSponsors = InfoService.instance.latestSponsors;
  if (cachedSponsors != null) {
    audioHandler.updateSponsorNames(
      cachedSponsors.map((s) => s.title).toList(),
    );
  }

  final sponsorSub = InfoService.instance.sponsorsStream.listen((sponsors) {
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
}

// ── Crashlytics helpers (web-safe) ──────────────────────────────────────────

void _recordError(
  Object e,
  StackTrace st, {
  String? reason,
  bool fatal = false,
}) {
  if (!_isMobile) return;
  FirebaseCrashlytics.instance.recordError(e, st, reason: reason, fatal: fatal);
}

void _recordFlutterFatalError(FlutterErrorDetails details) {
  if (!_isMobile) return;
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
  // AppCheck only has providers for Android, iOS, macOS, and Web.
  // Windows and Linux have none — skip to avoid a runtime crash.
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) return;

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
  // Chromecast SDK only supports Android and iOS.
  if (!_isMobile) return;

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
    await UserService.instance.init().timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        debugPrint('[main] UserService init timed out');
      },
    );
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
              return KeyedSubtree(key: ValueKey(isDark), child: child!);
            },
            home: const ApolloNav(),
          ),
        );
      },
    );
  }
}