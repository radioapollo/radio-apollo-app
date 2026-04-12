/* Event Screen

   This screen displays upcoming events related to the radio station.

   It includes:
   - a fixed header (logo + title)
   - a scrollable list of upcoming events loaded from Firestore
*/

import 'package:flutter/material.dart';
import '../models/event.dart';
import '../services/event_service.dart';
import '../theme/app_theme.dart';
import '../constants/constants.dart';

class EventScreen extends StatelessWidget {
  EventScreen({super.key});

  final _eventService = EventService();

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
                child: StreamBuilder<List<Event>>(
                  stream: _eventService.eventsStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.navyMedium),
                      );
                    }
                    if (snapshot.hasError) {
                      return const Center(
                        child: Text(
                          'Fout bij het laden van evenementen.',
                          style: AppTextStyles.noDataText,
                        ),
                      );
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(
                        child: Text(
                          'Geen evenementen gevonden.',
                          style: AppTextStyles.noDataText,
                        ),
                      );
                    }

                    final events = snapshot.data!;
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                        AppDimensions.paddingXLarge,
                        0,
                        AppDimensions.paddingXLarge,
                        AppDimensions.paddingXLarge,
                      ),
                      itemCount: events.length,
                      itemBuilder: (context, index) =>
                          _buildEventCard(context, events[index]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEventCard(BuildContext context, Event event) => Padding(
        padding:
            const EdgeInsets.only(bottom: AppDimensions.spaceLarge),
        child: GestureDetector(
          onTap: () => _showEventDetail(context, event),
          child: Container(
            padding: const EdgeInsets.all(AppDimensions.paddingLarge),
            decoration: AppDecorations.lightCard(),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(
                      AppDimensions.paddingSmall),
                  decoration: AppDecorations.iconContainer(
                      color: AppColors.cardBlue),
                  child: const Icon(Icons.event,
                      color: AppColors.primaryLight,
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
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.chevronIcon,
                  size: AppDimensions.iconMedium,
                ),
              ],
            ),
          ),
        ),
      );

  void _showEventDetail(BuildContext context, Event event) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusXLarge),
        ),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.4,
        minChildSize: 0.25,
        maxChildSize: 0.85,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.paddingXLarge,
            AppDimensions.paddingXLarge,
            AppDimensions.paddingXLarge,
            AppDimensions.space30,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(
                      bottom: AppDimensions.spaceLarge),
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(event.title, style: AppTextStyles.screenTitleSmall),
              const SizedBox(height: AppDimensions.spaceLarge),
              _iconRow(Icons.access_time, event.date),
              const SizedBox(height: AppDimensions.spaceSmall),
              _iconRow(Icons.location_on, event.location),
              const SizedBox(height: AppDimensions.spaceLarge),
              Text(event.what, style: AppTextStyles.cardSubtitle),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconRow(IconData icon, String label) => Row(
        children: [
          Icon(icon,
              size: AppDimensions.iconSmall, color: AppColors.textMeta),
          const SizedBox(width: AppDimensions.spaceXSmall),
          Text(label, style: AppTextStyles.cardMeta),
        ],
      );
}