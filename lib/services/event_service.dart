/* Event Service

   Provides a data stream for the Event screen.

   It handles:
   - streaming events from Firestore
   - filtering out events that are already in the past (before today)
   - sorting the remaining events by date, earliest first

   The stream is cached as a broadcast stream so screens can subscribe
   and re-subscribe across rebuilds without re-querying Firestore. The
   most recent value is also kept around so screens can use it as
   `initialData` on StreamBuilder and avoid a flash of loading state
   during rebuilds (e.g. page swipes).
*/

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/event.dart';
import '../utils/date_utils.dart';

class EventService {
  final _db = FirebaseFirestore.instance;

  Stream<List<Event>>? _eventsStream;
  List<Event>? _latestEvents;

  List<Event>? get latestEvents => _latestEvents;

  Stream<List<Event>> get eventsStream {
    return _eventsStream ??= _db.collection('evenementen').snapshots().map((
      snap,
    ) {
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);

      final events = snap.docs
          .map((doc) {
            final data = doc.data();
            // imageUrl is optional — older event documents won't have it,
            // and that's fine. The UI falls back to the default icon.
            final rawImageUrl = data['imageUrl'] as String?;
            return Event(
              title: data['title'] as String? ?? '',
              date: data['date'] as String? ?? '',
              location: data['location'] as String? ?? '',
              what: data['what'] as String? ?? '',
              imageUrl: rawImageUrl,
            );
          })
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

      _latestEvents = events;
      return events;
    }).asBroadcastStream();
  }
}
