/* Main Entry Point

   Initialises Firebase, loads the stored username, sets up the
   audio service, current-program service, and Cast context,
   then launches the app.
*/

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audio_service/audio_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';
import 'navigation/apollo_home.dart';
import 'services/audio_handler.dart';
import 'services/program/current_program_service.dart';
import 'services/chat/user_service.dart';
import 'widgets/service_provider.dart';
import 'firebase_options.dart';
import 'constants/constants.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Google Cast with the default media receiver
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
  }

  await UserService.instance.init();

  final audioHandler = await AudioService.init(
    builder: () => RadioAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: AppConstants.notificationChannelId,
      androidNotificationChannelName: AppConstants.notificationChannelName,
      androidNotificationOngoing: true,
    ),
  );

  final currentProgramService = CurrentProgramService();
  await currentProgramService.start();

  // Keep the audio handler in sync with the current program
  final programSub = currentProgramService.currentProgram.listen((program) {
    audioHandler.setCurrentProgram(
      program.title ?? '',
      imageUrl: program.imageUrl,
    );
  });

  runApp(ApolloApp(
    audioHandler: audioHandler,
    currentProgramService: currentProgramService,
    programSubscription: programSub,
  ));
}

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
        home: const ApolloHome(),
      ),
    );
  }
}