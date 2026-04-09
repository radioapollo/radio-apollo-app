/* Now Playing Program Card Widget

   This widget displays the currently airing radio program
   on the home screen, directly below the live player card.

   It shows:
   - the program image (or a fallback radio icon)
   - the program title
   - the presenter name
   - the time slot
   - a small "Nu bezig" indicator

   It fetches today's programs from Firestore and determines
   which one is currently on air. Refreshes every minute.

   On launch, it loads cached program data from shared_preferences
   so the card appears instantly without waiting for Firestore.

   It also updates the audio handler with the current program name
   and image so the media notification can display them.
*/

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../services/program_service.dart';
import '../theme/app_theme.dart';

class NowPlayingProgramCard extends StatefulWidget {
  final VoidCallback? onTap;

  const NowPlayingProgramCard({super.key, this.onTap});

  @override
  State<NowPlayingProgramCard> createState() => _NowPlayingProgramCardState();
}

class _NowPlayingProgramCardState extends State<NowPlayingProgramCard> {
  final _programService = ProgramService();
  Timer? _timer;

  // Cache keys
  static const _keyTitle     = 'now_playing_title';
  static const _keyPresenter = 'now_playing_presenter';
  static const _keyTimeSlot  = 'now_playing_time_slot';
  static const _keyImageUrl  = 'now_playing_image_url';

  String? _programTitle;
  String? _presenter;
  String? _timeSlot;
  String? _imageUrl;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCachedProgram();
    _loadCurrentProgram();
    _timer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _loadCurrentProgram(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ── Cache ─────────────────────────────────────────────────────────────────

  Future<void> _loadCachedProgram() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedTitle = prefs.getString(_keyTitle);

    if (cachedTitle != null && cachedTitle.isNotEmpty && mounted) {
      final cachedImageUrl = prefs.getString(_keyImageUrl);
      setState(() {
        _programTitle = cachedTitle;
        _presenter    = prefs.getString(_keyPresenter);
        _timeSlot     = prefs.getString(_keyTimeSlot);
        _imageUrl     = cachedImageUrl;
        _loading      = false;
      });
      audioHandler.setCurrentProgram(cachedTitle, imageUrl: cachedImageUrl);
    }
  }

  Future<void> _saveToCache() async {
    final prefs = await SharedPreferences.getInstance();
    if (_programTitle != null) {
      await prefs.setString(_keyTitle, _programTitle!);
      await prefs.setString(_keyPresenter, _presenter ?? '');
      await prefs.setString(_keyTimeSlot, _timeSlot ?? '');
      await prefs.setString(_keyImageUrl, _imageUrl ?? '');
    } else {
      await prefs.remove(_keyTitle);
      await prefs.remove(_keyPresenter);
      await prefs.remove(_keyTimeSlot);
      await prefs.remove(_keyImageUrl);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _formatTime(String time) {
    if (time == '24:00') return '00:00';
    return time;
  }

  bool _isCurrent(String startTime, String endTime) {
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;

    int parseTime(String time) {
      final parts = time.split(':');
      return int.parse(parts[0]) * 60 + int.parse(parts[1]);
    }

    final start = parseTime(startTime);
    final end = parseTime(endTime);

    if (end <= start) {
      return currentMinutes >= start || currentMinutes < end;
    }

    return currentMinutes >= start && currentMinutes < end;
  }

  // ── Firestore fetch ───────────────────────────────────────────────────────

  Future<void> _loadCurrentProgram() async {
    final todayName =
        ProgramService.weekdays[DateTime.now().weekday - 1];

    _programService.getProgramsForDay(todayName).first.then((programs) {
      if (!mounted) return;

      String? foundTitle;
      String? foundPresenter;
      String? foundTimeSlot;
      String? foundImageUrl;

      for (final p in programs) {
        final timeParts = p['time']!.split(' - ');
        if (timeParts.length == 2 && _isCurrent(timeParts[0], timeParts[1])) {
          foundTitle = p['title'];
          foundPresenter = p['desc'];
          foundImageUrl = p['imageUrl'];
          foundTimeSlot =
              '${_formatTime(timeParts[0])} - ${_formatTime(timeParts[1])}';
          break;
        }
      }

      setState(() {
        _programTitle = foundTitle;
        _presenter = foundPresenter;
        _timeSlot = foundTimeSlot;
        _imageUrl = foundImageUrl;
        _loading = false;
      });

      audioHandler.setCurrentProgram(foundTitle ?? '', imageUrl: foundImageUrl);

      _saveToCache();
    }).catchError((_) {
      if (mounted) setState(() => _loading = false);
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading || _programTitle == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingXLarge,
          vertical: AppDimensions.paddingMedium,
        ),
        decoration: BoxDecoration(
          color: AppColors.navyMedium,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
          border: Border.all(
            color: Colors.white12,
            width: AppDimensions.borderThin,
          ),
        ),
        child: Row(
          children: [
            // Program image or fallback radio icon
            ClipRRect(
              borderRadius:
                  BorderRadius.circular(AppDimensions.radiusSmall),
              child: _imageUrl != null && _imageUrl!.isNotEmpty
                  ? Image.network(
                      _imageUrl!,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          color: Colors.white12,
                        ),
                        child: const Icon(
                          Icons.radio,
                          color: Colors.white70,
                          size: AppDimensions.iconLarge,
                        ),
                      ),
                    )
                  : Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: Colors.white12,
                      ),
                      child: const Icon(
                        Icons.radio,
                        color: Colors.white70,
                        size: AppDimensions.iconLarge,
                      ),
                    ),
            ),
            const SizedBox(width: AppDimensions.spaceLarge),
            // Program info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // "Nu bezig" label + time
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.nuBezigBadgePaddingH,
                          vertical: AppDimensions.nuBezigBadgePaddingV,
                        ),
                        decoration: AppDecorations.nuBezigBadge(),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.circle,
                              size: AppDimensions.nuBezigIconSize,
                              color: Colors.greenAccent.shade400,
                            ),
                            const SizedBox(
                                width: AppDimensions.nuBezigIconSpacing),
                            const Text('Nu bezig',
                                style: AppTextStyles.nuBezigLabel),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppDimensions.spaceSmall),
                      if (_timeSlot != null)
                        Text(
                          _timeSlot!,
                          style: AppTextStyles.darkCardTime,
                        ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.spaceSmall),
                  // Program title
                  Text(
                    _programTitle!,
                    style: AppTextStyles.darkCardTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Presenter
                  if (_presenter != null && _presenter!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(
                          top: AppDimensions.spaceXSmall),
                      child: Text(
                        _presenter!,
                        style: AppTextStyles.darkCardSubtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            // Chevron to hint it navigates to programs
            if (widget.onTap != null)
              const Icon(
                Icons.chevron_right,
                color: Colors.white38,
                size: AppDimensions.iconLarge,
              ),
          ],
        ),
      ),
    );
  }
}