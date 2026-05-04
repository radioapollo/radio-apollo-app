/* Program Service

   This service manages the radio program schedule.

   It handles:
   - streaming program data from Firestore per weekday
   - one-shot fetches for today's schedule
   - returning a shifted day list so today is centered in the selector

   ─── Stream caching ────────────────────────────────────────────────────────
   Firestore queries are lazy — calling `.snapshots()` on a fresh query
   builds a brand new stream every time. If the UI did that on every
   rebuild, the StreamBuilder would reset to `ConnectionState.waiting`
   and flash a spinner during each rebuild (for example while the user
   swipes between bottom-nav tabs).

   Instead, we cache one broadcast stream per day. Multiple subscribers
   — or the same subscriber re-subscribing after a rebuild — all share
   the same underlying Firestore listener, so:
     - no extra database reads on rebuild
     - no loading flicker during tab swipes
     - real Firestore changes still propagate to every subscriber
*/

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/date_utils.dart';

class ProgramService {
  final _db = FirebaseFirestore.instance;

  final Map<String, Stream<List<Map<String, String>>>> _dayStreamCache = {};

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
    return _dayStreamCache.putIfAbsent(day, () {
      return _db
          .collection('programmatie')
          .where('day', isEqualTo: day)
          .snapshots()
          .map((snapshot) {
            final docs = snapshot.docs.toList();
            docs.sort(
              (a, b) => _s(
                a.data(),
                'startTime',
              ).compareTo(_s(b.data(), 'startTime')),
            );
            final programs = docs.map((doc) => _mapDoc(doc.data())).toList();

            _latestValueByDay[day] = programs;
            return programs;
          })
          .asBroadcastStream();
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
