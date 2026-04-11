/* Main Entry Point

   Initialises Firebase, loads the stored username, sets up the
   audio service, and launches the app.
*/

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audio_service/audio_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'navigation/apollo_home.dart';
import 'services/audio_handler.dart';
import 'services/chat/user_service.dart';
import 'firebase_options.dart';
import 'constants/constants.dart';

late final RadioAudioHandler audioHandler;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await UserService.instance.init();

  audioHandler = await AudioService.init(
    builder: () => RadioAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: AppConstants.notificationChannelId,
      androidNotificationChannelName: AppConstants.notificationChannelName,
      androidNotificationOngoing: true,
    ),
  );

  runApp(const ApolloApp());
}

class ApolloApp extends StatelessWidget {
  const ApolloApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Radio Apollo',
      theme: ThemeData(
        fontFamily: 'Sans',
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0A2342),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const ApolloHome(),
    );
  }
}