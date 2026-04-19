/* Event Service

   Provides a data stream for the Event screen.

   It handles:
   - streaming events from Firestore
   - filtering out events that are already in the past (before today)
   - sorting the remaining events by date, earliest first
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
        final today = DateTime.now();
        final todayStart = DateTime(today.year, today.month, today.day);

        final events = snap.docs
            .map((doc) => Event(
                  title:    doc['title']    ?? '',
                  date:     doc['date']     ?? '',
                  location: doc['location'] ?? '',
                  what:     doc['what']     ?? '',
                ))
            // ── Remove events whose date has already passed ─────────────
            // Events with an unparseable date are kept so they stay
            // visible instead of silently disappearing.
            .where((e) {
              final d = AppDateUtils.parseDutchDate(e.date);
              if (d == null) return true;
              final eventDay = DateTime(d.year, d.month, d.day);
              return !eventDay.isBefore(todayStart);
            })
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