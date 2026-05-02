/* Main Entry Point

   Initialises Firebase, Crashlytics, App Check, the audio service, the
   current-program service, and Cast context, then launches the app.

   Wraps async startup in a top-level error zone so uncaught errors are
   logged to Crashlytics rather than crashing the app silently.
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
import 'services/program/current_program_service.dart';
import 'services/chat/user_service.dart';
import 'services/chat/block_service.dart';
import 'utils/profanity/profanity_service.dart';
import 'services/notifications/notification_service.dart';
import 'widgets/service_provider.dart';
import 'firebase_options.dart';
import 'constants/constants.dart';
import 'theme/app_theme.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'services/chat/eula_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Create notification channels as early as possible — the FCM service
  // looks them up by ID and falls back to default if they don't exist.
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

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Firebase must come up before Crashlytics or any error handler that
  // wants to talk to Crashlytics. If Firebase itself fails, we render
  // the fallback screen and bail.
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

  // Disable Crashlytics in debug builds so "flutter run" doesn't pollute
  // the production crash dashboard with stack traces from development.
  await FirebaseCrashlytics.instance
      .setCrashlyticsCollectionEnabled(!kDebugMode);

  _installErrorHandlers();

  // Background message handler must be registered before any other
  // FCM API call. It's a no-op for now (FCM displays the notification
  // itself when the app isn't in the foreground) but having it wired
  // up means future silent-data messages will Just Work.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  await _activateAppCheck();

  // Notifications. Does not prompt — that happens on first interaction
  // with the Settings screen. Safe to fail silently if Firebase isn't
  // available (offline first launch on iOS, etc).
  try {
    await NotificationService.instance.init();
  } catch (e, st) {
    debugPrint('[main] NotificationService init failed: $e');
    FirebaseCrashlytics.instance.recordError(
      e,
      st,
      reason: 'NotificationService.init',
      fatal: false,
    );
  }

  // ── Firebase ──────────────────────────────────────────────────────────────

  if (!kIsWeb) await _initCast();

  await _initUser();

  try {
    await ProfanityService.instance.init();
  } catch (e, st) {
    debugPrint('[main] ProfanityService init failed: $e');
    FirebaseCrashlytics.instance.recordError(
      e,
      st,
      reason: 'ProfanityService.init',
      fatal: false,
    );
  }

  try {
    await BlockService.instance.init();
  } catch (e, st) {
    debugPrint('[main] BlockService init failed: $e');
    FirebaseCrashlytics.instance.recordError(
      e,
      st,
      reason: 'BlockService.init',
      fatal: false,
    );
  }

  try {
    await EulaService.instance.init();
  } catch (e, st) {
    debugPrint('[main] EulaService init failed: $e');
    FirebaseCrashlytics.instance.recordError(
      e, st,
      reason: 'EulaService.init',
      fatal: false,
    );
  }

  // ── Audio service (must succeed for the app to run) ───────────────────────

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
    FirebaseCrashlytics.instance.recordError(
      e,
      st,
      reason: 'AudioService.init (fatal)',
      fatal: true,
    );
    runApp(
      const _ErrorApp(
        message: 'Audiodienst kon niet starten. Herstart de app.',
      ),
    );
    return;
  }

  // ── Current program service ───────────────────────────────────────────────

  final currentProgramService = CurrentProgramService();
  try {
    await currentProgramService.start();
  } catch (e, st) {
    debugPrint('[main] CurrentProgramService start failed: $e');
    FirebaseCrashlytics.instance.recordError(
      e,
      st,
      reason: 'CurrentProgramService.start',
      fatal: false,
    );
  }

  final programSub = currentProgramService.currentProgram.listen((program) {
    audioHandler.setCurrentProgram(
      program.title ?? '',
      imageUrl: program.imageUrl,
    );
  });

  runApp(
    ApolloApp(
      audioHandler: audioHandler,
      currentProgramService: currentProgramService,
      programSubscription: programSub,
    ),
  );
}

// ── Startup helpers ─────────────────────────────────────────────────────────

void _installErrorHandlers() {
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('[FlutterError] ${details.exceptionAsString()}');
    // Forward fatal Flutter framework errors to Crashlytics.
    FirebaseCrashlytics.instance.recordFlutterFatalError(details);
  };
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('[UncaughtError] $error\n$stack');
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
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
    FirebaseCrashlytics.instance.recordError(
      e,
      st,
      reason: 'AppCheck.activate',
      fatal: false,
    );
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
        FirebaseCrashlytics.instance.recordError(
          e,
          st,
          reason: 'Cast discovery start',
          fatal: false,
        );
      }
    }
  } catch (e, st) {
    debugPrint('[main] Cast init failed: $e');
    FirebaseCrashlytics.instance.recordError(
      e,
      st,
      reason: 'Cast init',
      fatal: false,
    );
  }
}

Future<void> _initUser() async {
  try {
    await UserService.instance.init();
  } catch (e, st) {
    debugPrint('[main] UserService init failed: $e');
    FirebaseCrashlytics.instance.recordError(
      e,
      st,
      reason: 'UserService.init',
      fatal: false,
    );
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

  const ApolloApp({
    super.key,
    required this.audioHandler,
    required this.currentProgramService,
    required this.programSubscription,
  });

  @override
  State<ApolloApp> createState() => _ApolloAppState();
}

class _ApolloAppState extends State<ApolloApp> {
  @override
  void dispose() {
    widget.programSubscription.cancel();
    widget.currentProgramService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        home: const ApolloNav(),
      ),
    );
  }
}