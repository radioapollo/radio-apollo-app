/* Event Service

   Provides a data stream for the Event screen.

   It handles:
   - streaming events from Firestore ordered by date
*/

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/event.dart';

class EventService {
  final _db = FirebaseFirestore.instance;

  // ── Stream ────────────────────────────────────────────────────────────────

  Stream<List<Event>> get eventsStream => _db
      .collection('evenementen')
      .orderBy('date')
      .snapshots()
      .map((snap) => snap.docs
          .map((doc) => Event(
                title:    doc['title']    ?? '',
                date:     doc['date']     ?? '',
                location: doc['location'] ?? '',
                what:     doc['what']     ?? '',
              ))
          .toList());
}