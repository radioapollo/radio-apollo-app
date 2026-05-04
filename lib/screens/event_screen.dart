/* Event Screen

   This screen displays upcoming events related to the radio station.

   It includes:
   - a fixed header (logo + title)
   - a scrollable list of upcoming events loaded from Firestore
   - a one-shot snackbar announcing the soonest event within two weeks

   The screen itself is a thin orchestrator. All card rendering,
   badges, detail sheet, and the snackbar logic live in
   widgets/event/.

   The events stream is cached as a broadcast stream in EventService
   and captured once here in State so StreamBuilder keeps its last
   snapshot across rebuilds. That, plus `initialData` from the
   service's latest-value cache, means swiping into this tab doesn't
   flash an empty loader.
*/

import 'package:flutter/material.dart';
import '../models/event.dart';
import '../services/event_service.dart';
import '../widgets/event/event_card.dart';
import '../widgets/event/event_detail_sheet.dart';
import '../widgets/event/upcoming_event_snackbar.dart';
import '../theme/app_theme.dart';
import '../constants/constants.dart';

class EventScreen extends StatefulWidget {
  const EventScreen({super.key});

  @override
  State<EventScreen> createState() => _EventScreenState();
}

class _EventScreenState extends State<EventScreen>
    with AutomaticKeepAliveClientMixin {
  final _eventService = EventService();

  late final Stream<List<Event>> _eventsStream = _eventService.eventsStream;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SizedBox.expand(
      child: Container(
        decoration: const BoxDecoration(
          image: AppDecorations.backgroundWatermark,
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              Expanded(child: _buildEventList()),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
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
          const Text('Evenementen', style: AppTextStyles.screenTitle),
          const SizedBox(height: AppDimensions.spaceLarge),
        ],
      ),
    );
  }

  // ── Event list ────────────────────────────────────────────────────────────

  Widget _buildEventList() {
    return StreamBuilder<List<Event>>(
      stream: _eventsStream,
      initialData: _eventService.latestEvents,
      builder: (context, snapshot) {

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.navyMedium),
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
        UpcomingEventSnackbar.maybeShow(context, events);

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.paddingXLarge,
            0,
            AppDimensions.paddingXLarge,
            AppDimensions.paddingXLarge,
          ),
          itemCount: events.length,
          itemBuilder: (context, index) => EventCard(
            event: events[index],
            onTap: () => EventDetailSheet.show(context, events[index]),
          ),
        );
      },
    );
  }
}