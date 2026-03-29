/* Home Screen

   This is the main landing page of the application.

   It displays:
   - the live radio player
   - quick navigation cards
   - shortcuts to the program schedule, info page, and chat
*/

import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import '../main.dart'; // import the global audioHandler
import '../widgets/page_with_header.dart';
import '../widgets/apollo_card.dart';
import '../widgets/live_player_card.dart';

class HomeScreen extends StatelessWidget {
  final Function(int) onNavigate;
  const HomeScreen({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return PageWithHeader(
      child: Column(
        children: [
          StreamBuilder<PlaybackState>(
            stream: audioHandler.playbackState,
            builder: (context, snapshot) {
              final isPlaying = snapshot.data?.playing ?? false;

              return LivePlayerCard(
                isPlaying: isPlaying,
                onTap: audioHandler.toggle,
              );
            },
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
            title: "Programma's",
            subtitle: "Bekijk ons weekoverzicht",
            onTap: () => onNavigate(1),
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
            onTap: () => onNavigate(2),
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
      onTap: () => onNavigate(3),
      layout: CardLayout.horizontal,
    );
  }
}