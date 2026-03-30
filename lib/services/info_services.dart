/* Info Service

   This service provides data for the Info screen.

   It may handle:
   - retrieving sponsor information
   - loading announcements
   - managing station information
*/

import '../models/sponsor.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class InfoService {
  final _db = FirebaseFirestore.instance;

  Stream<List<Sponsor>> get sponsorsStream => _db
      .collection('sponsors')
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => Sponsor(
                title: doc['title'] ?? '',
                description: doc['description'] ?? '',
              ))
          .toList());

  final String aboutText = 
    "Radio Apollo staat voor feel-good muziek, lokale verbondenheid en een warme sfeer. "
    "We brengen een mix van classics, hedendaagse hits en lokale informatie.\n\n"
    "Onze missie is om luisteraars plezier, nieuws en gezelligheid te brengen – altijd en overal.";
}