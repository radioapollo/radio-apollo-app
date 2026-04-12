/* Live Player Card Widget

   This widget displays the live radio player on the home screen.

   It shows:
   - a play/pause button that controls the audio stream
   - the LIVE indicator and station name
   - the currently playing song, read from the audio handler's mediaItem stream
*/

import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'service_provider.dart';
import '../theme/app_theme.dart';

class LivePlayerCard extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onTap;

  const LivePlayerCard({
    super.key,
    required this.isPlaying,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final audioHandler = ServiceProvider.of(context).audioHandler;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingXLarge),
      decoration: AppDecorations.livePlayerCard(),
      child: Row(
        children: [
          GestureDetector(
            onTap: onTap,
            child: Icon(
              isPlaying
                  ? Icons.pause_circle_filled
                  : Icons.play_circle_fill,
              color: AppColors.textOnDark,
              size: AppDimensions.iconPlayPause,
            ),
          ),
          const SizedBox(width: AppDimensions.paddingLarge),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: AppDecorations.liveBadge(),
                  child:
                      const Text('● LIVE', style: AppTextStyles.liveLabel),
                ),
                const SizedBox(height: AppDimensions.spaceSmall),
                const Text('RADIO APOLLO',
                    style: AppTextStyles.stationName),
                const SizedBox(height: AppDimensions.spaceSmall),
                StreamBuilder<MediaItem?>(
                  stream: audioHandler.mediaItem,
                  builder: (context, snapshot) {
                    final item = snapshot.data;
                    final artist = item?.artist ?? '';
                    final title = item?.title ?? 'Live radio speelt...';

                    final showArtist =
                        artist.isNotEmpty && artist != 'Live';

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showArtist)
                          Text(artist,
                              style: AppTextStyles.playerArtist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        Text(title,
                            style: AppTextStyles.playerSong,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}