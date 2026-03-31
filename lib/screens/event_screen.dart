/* Event Screen

   This screen displays upcoming events related to the radio station.

   It includes:
   - a list of upcoming events
   - date, location, and description per event
*/

import 'package:flutter/material.dart';
import '../models/event.dart';
import '../widgets/page_with_header.dart';

class EventScreen extends StatelessWidget {
  const EventScreen({super.key});

  static final _events = [
    Event(
      title: 'Radio Apollo Zomerfeest',
      date: '12 juli 2025',
      location: 'Marktplein, Mechelen',
      what: 'Kom gezellig mee vieren met live muziek, optredens en veel fun!',
    ),
    Event(
      title: 'Open Studio Dag',
      date: '3 augustus 2025',
      location: 'Studio Apollo, Mechelen',
      what: 'Kom een kijkje nemen achter de schermen van jouw favoriete radiostation.',
    ),
    Event(
      title: 'Apollo Quiz Night',
      date: '21 augustus 2025',
      location: 'Café De Kroon, Mechelen',
      what: 'Test je kennis in onze legendarische muziekquiz. Inschrijven via de website.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return PageWithHeader(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Evenementen',
              style: TextStyle(
                  color: Colors.black,
                  fontSize: 26,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 15),
          ..._events.map(_buildEventCard),
        ],
      ),
    );
  }

  Widget _buildEventCard(Event event) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black12, width: 1.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFCDE7FF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.event, color: Color(0xFF0A2342), size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.title,
                      style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  _iconRow(Icons.access_time, event.date),
                  const SizedBox(height: 2),
                  _iconRow(Icons.location_on, event.location),
                  const SizedBox(height: 6),
                  Text(event.what,
                      style: const TextStyle(
                          color: Colors.black54, height: 1.3, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _iconRow(IconData icon, String label) => Row(
        children: [
          Icon(icon, size: 13, color: Colors.black45),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(color: Colors.black45, fontSize: 12)),
        ],
      );
}