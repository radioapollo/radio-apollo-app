/* Live Player Card

   This widget displays the live radio player.

   It includes:
   - a play/pause button
   - a live indicator
   - the current program information
   - the currently playing song fetched from Shoutcast
*/

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class LivePlayerCard extends StatefulWidget {
  final bool isPlaying;
  final VoidCallback onTap;

  const LivePlayerCard({
    super.key,
    required this.isPlaying,
    required this.onTap,
  });

  @override
  State<LivePlayerCard> createState() => _LivePlayerCardState();
}

class _LivePlayerCardState extends State<LivePlayerCard> {
  String _currentSong = "Nu te beluisteren";
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchCurrentSong();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _fetchCurrentSong());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchCurrentSong() async {
    try {
      final response = await http.get(
        Uri.parse('http://radioapollo.beheerstream.nl:8004/stats?json=1'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final song = data['songtitle'] ?? '';
        if (mounted && song.isNotEmpty) {
          setState(() => _currentSong = song);
        }
      }
    } catch (_) {
      // keep showing last known song on error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2F59),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.onTap,
            child: Icon(
              widget.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
              color: Colors.white,
              size: 70,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: const Text(
                    "● LIVE",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  "RADIO APOLLO",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _currentSong,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}