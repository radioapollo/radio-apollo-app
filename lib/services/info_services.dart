/* Info Service

   Provides data streams for the Info screen.

   It handles:
   - streaming the about text from Firestore
   - streaming the list of sponsors from Firestore
*/

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/sponsor.dart';
import '../constants/constants.dart';

class InfoService {
  final _db = FirebaseFirestore.instance;

  // ── Streams ───────────────────────────────────────────────────────────────

  Stream<String> get aboutTextStream => _db
      .collection('instellingen')
      .doc('info')
      .snapshots()
      .map((doc) => doc.data()?['text'] as String? ?? '');

  Stream<List<Sponsor>> get sponsorsStream => _db
      .collection(AppConstants.firestoreSponsors)
      .snapshots()
      .map((snap) => snap.docs
          .map((doc) => Sponsor(
                title:       doc['title']       ?? '',
                description: doc['description'] ?? '',
              ))
          .toList());
}