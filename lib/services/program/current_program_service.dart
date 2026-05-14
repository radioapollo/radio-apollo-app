/* Current Program Service

   Determines which radio program is currently on air and keeps
   the result cached in SharedPreferences so the UI can show it
   instantly on cold start.

   Also notifies the audio handler so the media notification
   displays the correct program name and artwork.

   Consumers listen to [currentProgram] for updates.

   ─── Split init for fast cold start ────────────────────────────────────────
   `start()` previously did three things sequentially: load the cached
   program from SharedPreferences, fetch the live program from
   Firestore, and start the 1-minute refresh timer. The Firestore
   fetch is a network round-trip; on a slow connection it would block
   the splash for seconds if main() awaited it.

   The service now exposes `loadCachedProgram()` separately: a tiny
   SharedPreferences-only call that emits the cached program. main()
   awaits this before runApp() so the LivePlayerCard renders with the
   right program name on the very first frame, then kicks off the
   full `start()` in the background. `start()` itself skips the
   redundant cache load when `loadCachedProgram()` has already run.
*/

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/date_utils.dart';
import 'program_service.dart';

class CurrentProgram {
  final String? title;
  final String? presenter;
  final String? timeSlot;
  final String? imageUrl;

  const CurrentProgram({
    this.title,
    this.presenter,
    this.timeSlot,
    this.imageUrl,
  });

  bool get hasData => title != null && title!.isNotEmpty;
}

class CurrentProgramService {
  final ProgramService _programService;

  CurrentProgramService({ProgramService? programService})
    : _programService = programService ?? ProgramService();

  // ── Cache keys ────────────────────────────────────────────────────────────

  static const _keyTitle = 'now_playing_title';
  static const _keyPresenter = 'now_playing_presenter';
  static const _keyTimeSlot = 'now_playing_time_slot';
  static const _keyImageUrl = 'now_playing_image_url';

  Timer? _timer;
  final _controller = StreamController<CurrentProgram>.broadcast();
  bool _cacheLoaded = false;

  Stream<CurrentProgram> get currentProgram => _controller.stream;

  CurrentProgram _lastProgram = const CurrentProgram();
  CurrentProgram get lastProgram => _lastProgram;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Load the cached program from SharedPreferences and emit it. Fast,
  /// local-only. Safe to call before `start()` to seed the UI with
  /// last-known data on cold start without waiting for Firestore.
  /// Idempotent.
  Future<void> loadCachedProgram() async {
    if (_cacheLoaded) return;
    _cacheLoaded = true;
    await _loadCachedProgram();
  }

  Future<void> start() async {
    if (!_cacheLoaded) {
      _cacheLoaded = true;
      await _loadCachedProgram();
    }
    await _fetchCurrentProgram();
    _timer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _fetchCurrentProgram(),
    );
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    if (!_controller.isClosed) _controller.close();
  }

  // ── Cache ─────────────────────────────────────────────────────────────────

  Future<void> _loadCachedProgram() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedTitle = prefs.getString(_keyTitle);

    if (cachedTitle != null && cachedTitle.isNotEmpty) {
      _emit(
        CurrentProgram(
          title: cachedTitle,
          presenter: prefs.getString(_keyPresenter),
          timeSlot: prefs.getString(_keyTimeSlot),
          imageUrl: prefs.getString(_keyImageUrl),
        ),
      );
    }
  }

  Future<void> _saveToCache(CurrentProgram p) async {
    final prefs = await SharedPreferences.getInstance();
    if (p.hasData) {
      await prefs.setString(_keyTitle, p.title!);
      await prefs.setString(_keyPresenter, p.presenter ?? '');
      await prefs.setString(_keyTimeSlot, p.timeSlot ?? '');
      await prefs.setString(_keyImageUrl, p.imageUrl ?? '');
    } else {
      await prefs.remove(_keyTitle);
      await prefs.remove(_keyPresenter);
      await prefs.remove(_keyTimeSlot);
      await prefs.remove(_keyImageUrl);
    }
  }

  // ── Firestore fetch ───────────────────────────────────────────────────────

  Future<void> _fetchCurrentProgram() async {
    try {
      final todayName = ProgramService.weekdays[DateTime.now().weekday - 1];

      final programs = await _programService.getProgramsForDayOnce(todayName);

      CurrentProgram result = const CurrentProgram();

      for (final p in programs) {
        final time = p['time'] ?? '';
        final timeParts = time.split(' - ');
        if (timeParts.length == 2 &&
            timeParts[0].isNotEmpty &&
            timeParts[1].isNotEmpty &&
            AppDateUtils.isCurrentTimeInRange(timeParts[0], timeParts[1])) {
          result = CurrentProgram(
            title: p['title'],
            presenter: p['desc'],
            imageUrl: p['imageUrl'],
            timeSlot: AppDateUtils.formatTimeRange(timeParts[0], timeParts[1]),
          );
          break;
        }
      }

      _emit(result);
      await _saveToCache(result);
    } catch (e) {
      debugPrint('[CurrentProgramService] fetch error: $e');
    }
  }

  void _emit(CurrentProgram p) {
    _lastProgram = p;
    if (!_controller.isClosed) {
      _controller.add(p);
    }
  }
}