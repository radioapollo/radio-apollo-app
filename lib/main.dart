import 'package:flutter/material.dart';
import 'navigation/apollo_home.dart';

void main() {
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