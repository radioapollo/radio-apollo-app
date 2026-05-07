/* Recently Played Sheet

   A draggable bottom sheet showing the last songs the stream has
   played, newest first. Subscribes to the audio handler's
   `recentSongsStream` so it updates live while the user has the sheet
   open — if a new song starts during scrolling, it appears at the top.

   Empty state
   ───────────
   If the user opens the sheet right after launching the app (before
   any metadata has been polled, or while the stream is paused) we
   show an explanatory message instead of an empty list.

   No persistence
   ──────────────
   The history lives only in memory in [RadioAudioHandler]. That's by
   design — see the model file for the rationale.
*/

import 'package:flutter/material.dart';
import '../../models/recent_song.dart';
import '../../services/audio_handler.dart';
import '../../theme/app_theme.dart';
import '../../utils/date_utils.dart';

class RecentlyPlayedSheet extends StatelessWidget {
  final RadioAudioHandler audioHandler;

  const RecentlyPlayedSheet({super.key, required this.audioHandler});

  static Future<void> show(
    BuildContext context,
    RadioAudioHandler audioHandler,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusXLarge),
        ),
      ),
      builder: (_) => RecentlyPlayedSheet(audioHandler: audioHandler),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDragHandle(),
            _buildHeader(),
            Expanded(
              child: StreamBuilder<List<RecentSong>>(
                stream: audioHandler.recentSongsStream,
                initialData: audioHandler.recentSongs,
                builder: (context, snapshot) {
                  final songs = snapshot.data ?? const <RecentSong>[];
                  if (songs.isEmpty) return _buildEmptyState();
                  return _buildList(songs, scrollController);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Header / handle ───────────────────────────────────────────────────────

  Widget _buildDragHandle() {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(top: AppDimensions.spaceMedium),
        decoration: BoxDecoration(
          color: AppColors.divider,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.paddingXLarge,
        AppDimensions.paddingLarge,
        AppDimensions.paddingXLarge,
        AppDimensions.spaceMedium,
      ),
      child: Text('Recent gespeeld', style: AppTextStyles.screenTitleSmall),
    );
  }

  // ── States ────────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppDimensions.paddingXLarge),
        child: Text(
          'Nog geen nummers geregistreerd. Start het afspelen om de '
          'lijst te vullen.',
          textAlign: TextAlign.center,
          style: AppTextStyles.noDataText,
        ),
      ),
    );
  }

  Widget _buildList(List<RecentSong> songs, ScrollController scrollController) {
    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.paddingXLarge,
        0,
        AppDimensions.paddingXLarge,
        AppDimensions.paddingXLarge,
      ),
      itemCount: songs.length,
      separatorBuilder: (_, _) =>
          const SizedBox(height: AppDimensions.spaceSmall),
      itemBuilder: (context, index) {
        return _RecentSongTile(song: songs[index], isFirst: index == 0);
      },
    );
  }
}

// ── Single row ──────────────────────────────────────────────────────────────

class _RecentSongTile extends StatelessWidget {
  final RecentSong song;
  final bool isFirst;

  const _RecentSongTile({required this.song, required this.isFirst});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingMedium,
        vertical: AppDimensions.paddingSmall + 2,
      ),
      decoration: AppDecorations.lightCard(),
      child: Row(
        children: [
          Icon(
            isFirst ? Icons.graphic_eq : Icons.music_note,
            color: isFirst ? AppColors.live : AppColors.textMeta,
            size: 20,
          ),
          const SizedBox(width: AppDimensions.spaceMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  song.title,
                  style: AppTextStyles.cardTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (song.artist.isNotEmpty)
                  Text(
                    song.artist,
                    style: AppTextStyles.cardSubtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppDimensions.spaceMedium),
          Text(
            AppDateUtils.formatTime(song.playedAt),
            style: AppTextStyles.cardMeta,
          ),
        ],
      ),
    );
  }
}
