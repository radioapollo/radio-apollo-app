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
  String _currentSong = "Live radio speelt...";
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchCurrentSong();
    _timer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _fetchCurrentSong(),
    );
  }

  @override
  void didUpdateWidget(covariant LivePlayerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !oldWidget.isPlaying) {
      _fetchCurrentSong();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchCurrentSong() async {
    if (!widget.isPlaying) return;

    try {
      final response = await http.get(
        Uri.parse('http://radioapollo.beheerstream.nl:8006/stats?json=1'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final song = (data['songtitle'] ?? '').toString().trim();

        if (!mounted) return;

        setState(() {
          _currentSong = song.isNotEmpty ? song : "Onbekend nummer";
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final parts = _currentSong.split(" - ");
    final artist = parts.length > 1 ? parts[0] : "";
    final title = parts.length > 1 ? parts[1] : _currentSong;

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
              widget.isPlaying
                  ? Icons.pause_circle_filled
                  : Icons.play_circle_fill,
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
                const SizedBox(height: 6),
                if (artist.isNotEmpty)
                  Text(
                    artist,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                  maxLines: 1,
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