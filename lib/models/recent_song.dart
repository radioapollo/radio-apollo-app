/* Recent Song Model

   A single entry in the "recently played" history.

   Built from the metadata polled every 10 seconds in the audio handler.
   Stores artist + title separately (parsed from the raw "Artist - Title"
   string) plus the wall-clock time at which the song first appeared.

   The history is in-memory only — it resets when the app is killed.
   That's intentional: a few hours of song history is plenty for the
   "wait, what was that?" use case, and persisting it would mean writing
   to disk every 10 seconds.
*/

class RecentSong {
  final String artist;
  final String title;
  final DateTime playedAt;

  const RecentSong({
    required this.artist,
    required this.title,
    required this.playedAt,
  });

  /// Parses a raw "Artist - Title" string into a [RecentSong].
  /// Falls back to using the whole string as the title when the
  /// separator is missing.
  factory RecentSong.parse(String raw, {DateTime? now}) {
    final ts = now ?? DateTime.now();
    final parts = raw.split(' - ');
    if (parts.length > 1) {
      return RecentSong(
        artist: parts[0].trim(),
        title: parts.sublist(1).join(' - ').trim(),
        playedAt: ts,
      );
    }
    return RecentSong(artist: '', title: raw.trim(), playedAt: ts);
  }

  /// Display string for sharing or copy-paste.
  String get display => artist.isNotEmpty ? '$artist - $title' : title;
}