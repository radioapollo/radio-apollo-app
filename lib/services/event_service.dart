/* Event Service

   Provides a data stream for the Event screen.

   It handles:
   - streaming events from Firestore ordered by date
*/

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/event.dart';
import '../utils/date_utils.dart';

class EventService {
  final _db = FirebaseFirestore.instance;

  Stream<List<Event>> get eventsStream => _db
      .collection('evenementen')
      .snapshots()
      .map((snap) {
        final events = snap.docs
            .map((doc) => Event(
                  title:    doc['title']    ?? '',
                  date:     doc['date']     ?? '',
                  location: doc['location'] ?? '',
                  what:     doc['what']     ?? '',
                ))
            .toList();

        events.sort((a, b) {
          final dateA = AppDateUtils.parseDutchDate(a.date);
          final dateB = AppDateUtils.parseDutchDate(b.date);

          if (dateA == null && dateB == null) return 0;
          if (dateA == null) return 1;
          if (dateB == null) return -1;

          return dateA.compareTo(dateB);
        });

        return events;
      });
}