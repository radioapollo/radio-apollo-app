/* Live Player Card Widget

   This widget combines the live radio player and the currently airing
   program info into a single, visually rich card on the home screen.

   It shows:
   - the program background image (faded, decorative)
   - a LIVE badge with the current time slot
   - a Chromecast button (mobile only) next to the LIVE badge, visible
     whenever at least one Cast device is discovered on the network
     or a session is already active
   - the program title (instead of "Radio Apollo")
   - the presenter name
   - the currently playing song (from the audio handler's mediaItem stream)
   - a play/pause button

   The entire card is tappable to navigate to the programs screen.
*/

import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'service_provider.dart';
import 'cast_button.dart';
import '../services/program/current_program_service.dart';
import '../theme/app_theme.dart';

class LivePlayerCard extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onPlayPause;
  final VoidCallback? onTap;

  const LivePlayerCard({
    super.key,
    required this.isPlaying,
    required this.onPlayPause,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final services = ServiceProvider.of(context);
    final audioHandler = services.audioHandler;
    final cpService = services.currentProgramService;

    return StreamBuilder<CurrentProgram>(
      stream: cpService.currentProgram,
      initialData: cpService.lastProgram,
      builder: (context, programSnapshot) {
        final program = programSnapshot.data;
        final hasProgram = program != null && program.hasData;

        return GestureDetector(
          onTap: onTap,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: AppDecorations.livePlayerCard(),
            child: Stack(
              children: [
                // ── Background program image ────────────────────────
                if (hasProgram &&
                    program.imageUrl != null &&
                    program.imageUrl!.isNotEmpty) ...[
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.35,
                      child: CachedNetworkImage(
                        imageUrl: program.imageUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                  ),

                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            AppColors.navyDark,
                            AppColors.navyDark.withValues(alpha: 0.85),
                            AppColors.navyDark.withValues(alpha: 0.3),
                          ],
                          stops: const [0.0, 0.45, 1.0],
                        ),
                      ),
                    ),
                  ),
                ],

                // ── Foreground content ──────────────────────────────
                Padding(
                  padding: const EdgeInsets.all(AppDimensions.paddingXLarge),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: AppDecorations.liveBadge(),
                            child: const Text(
                              '● LIVE',
                              style: AppTextStyles.liveLabel,
                            ),
                          ),
                          if (hasProgram && program.timeSlot != null) ...[
                            const SizedBox(width: AppDimensions.spaceSmall),
                            Text(
                              program.timeSlot!,
                              style: AppTextStyles.darkCardTime,
                            ),
                          ],
                          const Spacer(),

                          const CastButton(size: 22),
                          if (onTap != null) ...[
                            const SizedBox(width: AppDimensions.spaceMedium),
                            const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Programma',
                                  style: TextStyle(
                                    color: AppColors.textOnDarkMuted,
                                    fontSize: 12,
                                  ),
                                ),
                                SizedBox(width: 2),
                                Icon(
                                  Icons.chevron_right,
                                  color: AppColors.textOnDarkMuted,
                                  size: 18,
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: AppDimensions.spaceMedium),

                      Row(
                        children: [

                          GestureDetector(
                            onTap: onPlayPause,
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

                                Text(
                                  hasProgram ? program.title! : 'RADIO APOLLO',
                                  style: AppTextStyles.stationName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),

                                if (hasProgram &&
                                    program.presenter != null &&
                                    program.presenter!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: AppDimensions.spaceXSmall,
                                    ),
                                    child: Text(
                                      program.presenter!,
                                      style: AppTextStyles.darkCardSubtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),

                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: AppDimensions.spaceSmall,
                                  ),
                                  child: StreamBuilder<MediaItem?>(
                                    stream: audioHandler.mediaItem,
                                    builder: (context, snapshot) {
                                      final item = snapshot.data;
                                      final artist = item?.artist ?? '';
                                      final title = item?.title ?? '';
                                      final display =
                                          artist.isNotEmpty && title.isNotEmpty
                                          ? '$artist - $title'
                                          : title.isNotEmpty
                                          ? title
                                          : 'Luister live';
                                      return Text(
                                        display,
                                        style: const TextStyle(
                                          color: AppColors.textOnDarkMuted,
                                          fontSize: 13,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
