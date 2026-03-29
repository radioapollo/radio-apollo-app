import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'navigation/apollo_home.dart';
import 'services/audio_handler.dart';

late final RadioAudioHandler audioHandler;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  audioHandler = await AudioService.init(
    builder: () => RadioAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'nl.radioapollo.channel.audio',
      androidNotificationChannelName: 'Radio Apollo',
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
        scaffoldBackgroundColor: const Color(0xFF0A2342),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0A2342),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const ApolloHome(),
    );
  }
}