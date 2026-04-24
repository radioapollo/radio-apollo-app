/* Info Service

   Provides data streams for the Info screen.

   It handles:
   - streaming the about text from Firestore
   - streaming the list of sponsors from Firestore

   ─── Stream caching ────────────────────────────────────────────────────────
   Both streams are built once as broadcast streams and reused across
   rebuilds. Each stream also remembers its latest emitted value so
   screens can pass that as `initialData` to `StreamBuilder` and avoid
   a flash of "loading" when the widget rebuilds (e.g. during a page
   swipe).
*/

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/sponsor.dart';
import '../constants/constants.dart';

class InfoService {
  final _db = FirebaseFirestore.instance;

  Stream<String>? _aboutTextStream;
  Stream<List<Sponsor>>? _sponsorsStream;

  String? _latestAboutText;
  List<Sponsor>? _latestSponsors;

  String? get latestAboutText => _latestAboutText;
  List<Sponsor>? get latestSponsors => _latestSponsors;

  // ── Streams ───────────────────────────────────────────────────────────────

  Stream<String> get aboutTextStream {
    return _aboutTextStream ??= _db
        .collection('instellingen')
        .doc('info')
        .snapshots()
        .map((doc) {
          final text = doc.data()?['text'] as String? ?? '';
          _latestAboutText = text;
          return text;
        })
        .asBroadcastStream();
  }

  Stream<List<Sponsor>> get sponsorsStream {
    return _sponsorsStream ??= _db
        .collection(AppConstants.firestoreSponsors)
        .snapshots()
        .map((snap) {
          final sponsors = snap.docs.map((doc) {
            final data = doc.data();
            return Sponsor(
              title: data['title'] ?? '',
              description: data['description'] ?? '',
              imageUrl: data['imageUrl'] as String?,
            );
          }).toList();
          _latestSponsors = sponsors;
          return sponsors;
        })
        .asBroadcastStream();
  }
}