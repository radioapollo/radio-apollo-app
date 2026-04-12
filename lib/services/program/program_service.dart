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

  Stream<List<Map<String, String>>> getProgramsForDay(String day) {
    return _db
        .collection('programmatie')
        .where('day', isEqualTo: day)
        .snapshots()
        .map((snapshot) {
          final docs = snapshot.docs;
          docs.sort((a, b) =>
              (a['startTime'] as String).compareTo(b['startTime'] as String));
          return docs
              .map((doc) {
                    final data = doc.data();
                    return {
                      'time': '${doc['startTime']} - ${doc['endTime']}',
                      'title': doc['title'] as String,
                      'desc': doc['presenter'] as String,
                      'imageUrl': data.containsKey('imageUrl')
                          ? (doc['imageUrl'] as String? ?? '')
                          : '',
                    };
                  })
              .toList();
        });
  }

  List<String> getShiftedDays(int selectedIndex) {
    final shift = DateTime.now().weekday - (selectedIndex + 1);
    return AppDateUtils.shiftList(List.from(weekdays), shift);
  }
}