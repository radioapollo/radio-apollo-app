/* Info Service

   This service provides data for the Info screen.

   It handles:
   - streaming sponsor information from Firestore
   - streaming the about text from Firestore
*/

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/sponsor.dart';
import '../constants/constants.dart';

class InfoService {
  final _db = FirebaseFirestore.instance;

  Stream<List<Sponsor>> get sponsorsStream => _db
      .collection(AppConstants.firestoreSponsors)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => Sponsor(
                title: doc['title'] ?? '',
                description: doc['description'] ?? '',
              ))
          .toList());

  Stream<String> get aboutTextStream => _db
      .collection('instellingen')
      .doc('info')
      .snapshots()
      .map((doc) => doc.data()?['text'] as String? ?? '');
}