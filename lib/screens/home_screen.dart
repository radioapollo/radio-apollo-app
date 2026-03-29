/* Home Screen

   This is the main landing page of the application.

   It displays:
   - the live radio player
   - quick navigation cards
   - shortcuts to the program schedule, info page, and chat
*/

import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import '../main.dart';
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
          _buildBottomRow(),
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
            border: Border.all(color: Colors.black12, width: 1.5),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ApolloCard(
            color: const Color(0xFF185ADB),
            icon: Icons.campaign,
            title: "Info",
            subtitle: "Wie zijn wij en onze adverteerders",
            darkText: true,
            onTap: () => onNavigate(2),
            layout: CardLayout.vertical,
            border: Border.all(color: Colors.black12, width: 1.5),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomRow() {
    return Row(
      children: [
        Expanded(
          child: ApolloCard(
            color: const Color(0xFFCBF0D8),
            icon: Icons.event,
            title: "Evenementen",
            subtitle: "Bekijk onze evenementen",
            onTap: () => onNavigate(3),
            layout: CardLayout.vertical,
            border: Border.all(color: Colors.black12, width: 1.5),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ApolloCard(
            color: const Color(0xFFCDE7FF),
            icon: Icons.chat_bubble,
            title: "Chat",
            subtitle: "Stuur een bericht naar de studio",
            onTap: () => onNavigate(4),
            layout: CardLayout.vertical,
            border: Border.all(color: Colors.black12, width: 1.5),
          ),
        ),
      ],
    );
  }
}