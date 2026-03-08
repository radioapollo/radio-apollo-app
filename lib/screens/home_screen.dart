/* Home Screen

   This is the main landing page of the application.

   It displays:
   - the live radio player
   - quick navigation cards
   - shortcuts to the program schedule, info page, and chat
*/

import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../widgets/page_with_header.dart';
import '../widgets/apollo_card.dart';
import '../widgets/live_player_card.dart';

class HomeScreen extends StatefulWidget {
  final Function(int) onNavigate;
  const HomeScreen({super.key, required this.onNavigate});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final AudioService _audioService;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _audioService = AudioService();
    
    _audioService.playStateStream.listen((isPlaying) {
      if (mounted) {
        setState(() {
          _isPlaying = isPlaying;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageWithHeader(
      child: Column(
        children: [
          LivePlayerCard(
            isPlaying: _isPlaying,
            onTap: _audioService.togglePlay,
          ),
          const SizedBox(height: 30),
          _buildNavigationRow(),
          const SizedBox(height: 16),
          _buildChatCard(),
        ],
      ),
    );
  }

  Widget _buildNavigationRow() {
    return Row(
      children: [
        Expanded(
          child: ApolloCard(
            color: const Color(0xFFFFF4CE),
            icon: Icons.calendar_month,
            title: "Programma’s",
            subtitle: "Bekijk ons weekoverzicht",
            onTap: () => widget.onNavigate(1),
            layout: CardLayout.vertical,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ApolloCard(
            color: const Color(0xFF185ADB),
            icon: Icons.campaign,
            title: "Info",
            subtitle: "Nieuwtjes, evenementen en reclame",
            darkText: true,
            onTap: () => widget.onNavigate(2),
            layout: CardLayout.vertical,
          ),
        ),
      ],
    );
  }

  Widget _buildChatCard() {
    return ApolloCard(
      color: const Color(0xFFCDE7FF),
      icon: Icons.chat_bubble,
      title: "Chat",
      subtitle: "Stuur een bericht naar de studio",
      big: true,
      onTap: () => widget.onNavigate(3),
      layout: CardLayout.horizontal,
    );
  }
}