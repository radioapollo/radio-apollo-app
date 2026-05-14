/* Program Service

   This service manages the radio program schedule.

   It handles:
   - streaming program data from Firestore per weekday
   - one-shot fetches for today's schedule
   - returning a shifted day list so today is centered in the selector

   ─── Why we no longer cache a broadcast stream ─────────────────────────────
   An earlier version cached one `.asBroadcastStream()` per day. That
   prevented spinner flashes on tab swipe, but introduced a far worse
   bug: broadcast streams do NOT replay the last value to late
   subscribers. When a user navigated away from a day and came back,
   the StreamBuilder re-subscribed to the same warm broadcast stream,
   got no replay, and ended up displaying stale data from the
   previously-viewed day (or whichever `initialData` happened to be
   handed in at that frame). The most visible symptom was the wrong
   programs and a misplaced "NU BEZIG" highlight when revisiting a
   day after browsing others.

   Firestore's `.snapshots()` stream already handles re-subscription
   correctly — every new listener receives the current cached
   snapshot immediately. So we now:
     1. Build a fresh `.snapshots().map(...)` chain on each call.
     2. Continue to write into `_latestValueByDay` from inside the
        `.map()` closure so consumers can prime `StreamBuilder` with
        `initialData` to avoid the spinner flash.

   The Firestore SDK has its own local cache, so even though we build
   a new query each time, repeated subscriptions don't trigger
   additional network reads — the client returns the cached snapshot.
*/

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/date_utils.dart';

class ProgramService {
  final _db = FirebaseFirestore.instance;

  final Map<String, List<Map<String, String>>> _latestValueByDay = {};

  List<Map<String, String>>? latestForDay(String day) => _latestValueByDay[day];

  static const List<String> weekdays = [
    'Maandag',
    'Dinsdag',
    'Woensdag',
    'Donderdag',
    'Vrijdag',
    'Zaterdag',
    'Zondag',
  ];

  static String getWeekdayName(int weekday) => weekdays[weekday - 1];

  // ── Internal helpers ──────────────────────────────────────────────────────

  static String _s(Map<String, dynamic> data, String key) {
    final v = data[key];
    return v is String ? v : '';
  }

  static Map<String, String> _mapDoc(Map<String, dynamic> data) {
    final startTime = _s(data, 'startTime');
    final endTime = _s(data, 'endTime');
    return {
      'time': '$startTime - $endTime',
      'title': _s(data, 'title'),
      'desc': _s(data, 'presenter'),
      'imageUrl': _s(data, 'imageUrl'),
    };
  }

  // ── Live stream ───────────────────────────────────────────────────────────

  Stream<List<Map<String, String>>> getProgramsForDay(String day) {
    return _db
        .collection('programmatie')
        .where('day', isEqualTo: day)
        .snapshots()
        .map((snapshot) {
          final docs = snapshot.docs.toList();
          docs.sort(
            (a, b) =>
                _s(a.data(), 'startTime').compareTo(_s(b.data(), 'startTime')),
          );
          final programs = docs.map((doc) => _mapDoc(doc.data())).toList();

          _latestValueByDay[day] = programs;
          return programs;
        });
  }

  // ── One-shot fetch ────────────────────────────────────────────────────────

  Future<List<Map<String, String>>> getProgramsForDayOnce(String day) async {
    try {
      final snap = await _db
          .collection('programmatie')
          .where('day', isEqualTo: day)
          .get();

      final docs = snap.docs.toList();
      docs.sort(
        (a, b) =>
            _s(a.data(), 'startTime').compareTo(_s(b.data(), 'startTime')),
      );
      return docs.map((doc) => _mapDoc(doc.data())).toList();
    } catch (_) {
      return const [];
    }
  }

  // ── Day selector ──────────────────────────────────────────────────────────

  List<String> getShiftedDays(int selectedIndex) {
    final shift = DateTime.now().weekday - (selectedIndex + 1);
    return AppDateUtils.shiftList(List.from(weekdays), shift);
  }
}
