/* Program Service

   This service manages the radio program schedule.

   It handles:
   - fetching program data from Firestore per weekday
   - returning a shifted day list so today is centered in the selector
*/

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/date_utils.dart';

class ProgramService {
  final _db = FirebaseFirestore.instance;

  static const List<String> weekdays = [
    'Maandag', 'Dinsdag', 'Woensdag', 'Donderdag',
    'Vrijdag', 'Zaterdag', 'Zondag',
  ];

  static String getWeekdayName(int weekday) => weekdays[weekday - 1];

  /// Safe string read that never throws on a missing field.
  static String _s(Map<String, dynamic> data, String key) {
    final v = data[key];
    return v is String ? v : '';
  }

  Stream<List<Map<String, String>>> getProgramsForDay(String day) {
    return _db
        .collection('programmatie')
        .where('day', isEqualTo: day)
        .snapshots()
        .map((snapshot) {
          // FIX: read via .data() with safe defaults — a missing startTime
          // on any single doc no longer blows up the whole stream.
          final docs = snapshot.docs.toList();
          docs.sort((a, b) =>
              _s(a.data(), 'startTime').compareTo(_s(b.data(), 'startTime')));
          return docs.map((doc) {
            final data = doc.data();
            final startTime = _s(data, 'startTime');
            final endTime = _s(data, 'endTime');
            return {
              'time': '$startTime - $endTime',
              'title': _s(data, 'title'),
              'desc': _s(data, 'presenter'),
              'imageUrl': _s(data, 'imageUrl'),
            };
          }).toList();
        });
  }

  /// One-shot fetch for today's schedule (cheaper than opening a live stream
  /// just to read `.first`). Used by CurrentProgramService.
  Future<List<Map<String, String>>> getProgramsForDayOnce(String day) async {
    try {
      final snap = await _db
          .collection('programmatie')
          .where('day', isEqualTo: day)
          .get();

      final docs = snap.docs.toList();
      docs.sort((a, b) =>
          _s(a.data(), 'startTime').compareTo(_s(b.data(), 'startTime')));
      return docs.map((doc) {
        final data = doc.data();
        final startTime = _s(data, 'startTime');
        final endTime = _s(data, 'endTime');
        return {
          'time': '$startTime - $endTime',
          'title': _s(data, 'title'),
          'desc': _s(data, 'presenter'),
          'imageUrl': _s(data, 'imageUrl'),
        };
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  List<String> getShiftedDays(int selectedIndex) {
    final shift = DateTime.now().weekday - (selectedIndex + 1);
    return AppDateUtils.shiftList(List.from(weekdays), shift);
  }
}