/* Main Entry Point

   Initialises Firebase, loads the stored username, sets up the
   audio service, current-program service, and Cast context,
   then launches the app.

   Includes a top-level error zone so uncaught async errors and
   Flutter framework errors are logged instead of crashing the app.
*/

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:audio_service/audio_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';
import 'navigation/apollo_nav.dart';
import 'services/audio_handler.dart';
import 'services/program/current_program_service.dart';
import 'services/chat/user_service.dart';
import 'widgets/service_provider.dart';
import 'firebase_options.dart';
import 'constants/constants.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Top-level error handling ──────────────────────────────────────────────

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('[FlutterError] ${details.exceptionAsString()}');
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('[UncaughtError] $error\n$stack');
    return true;
  };

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // ── Firebase ──────────────────────────────────────────────────────────────

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

  // ── Google Cast ───────────────────────────────────────────────────────────

  if (!kIsWeb) {
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

        // Start actively scanning for Cast devices so the cast button
        // on the home screen can light up as soon as a Chromecast is
        // visible on the local network. This is the fix for "Cast
        // knop is weg" — without an active discovery the UI never
        // sees any devices.
        try {
          GoogleCastDiscoveryManager.instance.startDiscovery();
        } catch (e) {
          debugPrint('[main] Cast discovery start failed: $e');
        }
      }
    } catch (e) {
      debugPrint('[main] Cast init failed: $e');
    }
  }

  // ── User identity ─────────────────────────────────────────────────────────

  try {
    await UserService.instance.init();
  } catch (e) {
    debugPrint('[main] UserService init failed: $e');
  }

  // ── Audio service ─────────────────────────────────────────────────────────

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
  } catch (e) {
    debugPrint('[main] AudioService init failed: $e');
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
  } catch (e) {
    debugPrint('[main] CurrentProgramService start failed: $e');
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