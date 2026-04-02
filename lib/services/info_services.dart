/* Info Service

   This service provides data for the Info screen.

   It handles:
   - streaming sponsor information from Firestore
   - providing the station's about text
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
}