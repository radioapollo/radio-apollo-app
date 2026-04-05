/* Event Service

   This service provides data for the Event screen.

   It handles:
   - streaming event data from Firestore
   - events are stored in the 'evenementen' collection
*/

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/event.dart';

class EventService {
  final _db = FirebaseFirestore.instance;

  Stream<List<Event>> get eventsStream => _db
      .collection('evenementen')
      .orderBy('date')
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => Event(
                title: doc['title'] ?? '',
                date: doc['date'] ?? '',
                location: doc['location'] ?? '',
                what: doc['what'] ?? '',
              ))
          .toList());
}