/* Home Screen

   This is the main landing page of the application.

   It displays:
   - the live radio player
   - quick navigation cards to the schedule, info, events, and chat
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
            builder: (context, snapshot) => LivePlayerCard(
              isPlaying: snapshot.data?.playing ?? false,
              onTap: audioHandler.toggle,
            ),
          ),
          const SizedBox(height: 30),
          _buildRow([
            _card(color: const Color(0xFFFFF4CE), icon: Icons.calendar_month,
                title: "Programma's", subtitle: 'Bekijk ons weekoverzicht', index: 1),
            _card(color: const Color(0xFF185ADB), icon: Icons.campaign,
                title: 'Info', subtitle: 'Wie zijn wij en onze adverteerders',
                darkText: true, index: 2),
          ]),
          const SizedBox(height: 16),
          _buildRow([
            _card(color: const Color(0xFFCBF0D8), icon: Icons.event,
                title: 'Evenementen', subtitle: 'Bekijk onze evenementen', index: 3),
            _card(color: const Color(0xFFCDE7FF), icon: Icons.chat_bubble,
                title: 'Chat', subtitle: 'Stuur een bericht naar de studio', index: 4),
          ]),
        ],
      ),
    );
  }

  Widget _buildRow(List<Widget> children) => Row(
        children: [
          Expanded(child: children[0]),
          const SizedBox(width: 16),
          Expanded(child: children[1]),
        ],
      );

  Widget _card({
    required Color color,
    required IconData icon,
    required String title,
    required String subtitle,
    required int index,
    bool darkText = false,
  }) =>
      ApolloCard(
        color: color,
        icon: icon,
        title: title,
        subtitle: subtitle,
        darkText: darkText,
        onTap: () => onNavigate(index),
        layout: CardLayout.vertical,
        border: Border.all(color: Colors.black12, width: 1.5),
      );
}