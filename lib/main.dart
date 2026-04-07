import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'navigation/apollo_home.dart';
import 'services/audio_handler.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'constants/constants.dart';

late final RadioAudioHandler audioHandler;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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