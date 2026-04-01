/* Event Screen

   This screen displays upcoming events related to the radio station.

   It includes:
   - a list of upcoming events
   - date, location, and description per event
*/

import 'package:flutter/material.dart';
import '../models/event.dart';
import '../widgets/page_with_header.dart';
import '../theme/app_theme.dart';

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
      what:
          'Kom een kijkje nemen achter de schermen van jouw favoriete radiostation.',
    ),
    Event(
      title: 'Apollo Quiz Night',
      date: '21 augustus 2025',
      location: 'Café De Kroon, Mechelen',
      what:
          'Test je kennis in onze legendarische muziekquiz. Inschrijven via de website.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return PageWithHeader(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Evenementen', style: AppTextStyles.screenTitle),
          const SizedBox(height: AppDimensions.spaceLarge - 1),
          ..._events.map(_buildEventCard),
        ],
      ),
    );
  }

  Widget _buildEventCard(Event event) => Container(
        margin: const EdgeInsets.only(bottom: AppDimensions.spaceXLarge),
        padding: const EdgeInsets.all(AppDimensions.paddingMedium),
        decoration: AppDecorations.lightCard(),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(AppDimensions.paddingSmall),
              decoration: AppDecorations.iconContainer(
                  color: AppColors.cardBlue,
                  radius: AppDimensions.radiusSmall),
              child: const Icon(Icons.event,
                  color: AppColors.primary, size: AppDimensions.iconLarge),
            ),
            const SizedBox(width: AppDimensions.spaceLarge),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.title, style: AppTextStyles.cardTitle),
                  const SizedBox(height: AppDimensions.spaceXSmall),
                  _iconRow(Icons.access_time, event.date),
                  const SizedBox(height: 2),
                  _iconRow(Icons.location_on, event.location),
                  const SizedBox(height: AppDimensions.spaceSmall),
                  Text(event.what, style: AppTextStyles.cardSubtitle),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _iconRow(IconData icon, String label) => Row(
        children: [
          Icon(icon, size: AppDimensions.iconSmall, color: Colors.black45),
          const SizedBox(width: AppDimensions.spaceXSmall),
          Text(label, style: AppTextStyles.cardMeta),
        ],
      );
}