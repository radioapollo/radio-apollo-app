/* Event Screen

   This screen displays upcoming events related to the radio station.

   It includes:
   - a fixed header (logo + title)
   - a scrollable list of upcoming events
*/

import 'package:flutter/material.dart';
import '../models/event.dart';
import '../theme/app_theme.dart';
import '../constants/constants.dart';

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
    return SizedBox.expand(
      child: Container(
        decoration: const BoxDecoration(
          image: AppDecorations.backgroundWatermark,
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fixed header
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.paddingXLarge,
                  AppDimensions.paddingXLarge,
                  AppDimensions.paddingXLarge,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Image.asset(
                      AppAssets.logo,
                      height: AppDimensions.logoHeight,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: AppDimensions.spaceMedium),
                    const Text('Evenementen',
                        style: AppTextStyles.screenTitle),
                    const SizedBox(height: AppDimensions.spaceLarge),
                  ],
                ),
              ),

              // Scrollable event list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimensions.paddingXLarge,
                    0,
                    AppDimensions.paddingXLarge,
                    AppDimensions.paddingXLarge,
                  ),
                  itemCount: _events.length,
                  itemBuilder: (context, index) =>
                      _buildEventCard(_events[index]),
                ),
              ),
            ],
          ),
        ),
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
                  color: AppColors.primary,
                  size: AppDimensions.iconLarge),
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
          Icon(icon,
              size: AppDimensions.iconSmall, color: Colors.black45),
          const SizedBox(width: AppDimensions.spaceXSmall),
          Text(label, style: AppTextStyles.cardMeta),
        ],
      );
}