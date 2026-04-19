/* Event Screen

   This screen displays upcoming events related to the radio station.

   It includes:
   - a fixed header (logo + title)
   - a scrollable list of upcoming events loaded from Firestore
   - a "Binnenkort" / "Bijna" badge on each event card when it is close
   - visual highlights for upcoming events (colored accent bar, enhanced styling)
   - consistent card heights with truncated descriptions (tap to see full details)
   - a one-shot snackbar shown a few seconds after opening the screen
     when there is at least one event within the next two weeks
*/

import 'package:flutter/material.dart';
import '../models/event.dart';
import '../services/event_service.dart';
import '../theme/app_theme.dart';
import '../constants/constants.dart';

class EventScreen extends StatefulWidget {
  const EventScreen({super.key});

  @override
  State<EventScreen> createState() => _EventScreenState();
}

class _EventScreenState extends State<EventScreen> {
  final _eventService = EventService();

  // Shown snackbar only once per app session so the user is not spammed.
  // Static so it persists across tab switches but resets on app restart.
  static bool _popupShownThisSession = false;

  void _maybeShowUpcomingPopup(List<Event> events) {
    if (_popupShownThisSession) return;

    // Find the soonest event inside the next two weeks.
    Event? soonest;
    for (final e in events) {
      if (!e.isWithinTwoWeeks) continue;
      if (soonest == null ||
          (e.daysUntil ?? 999) < (soonest.daysUntil ?? 999)) {
        soonest = e;
      }
    }
    if (soonest == null) return;

    _popupShownThisSession = true;

    final days = soonest.daysUntil ?? 0;
    final label = days == 0
        ? 'Vandaag: ${soonest.title}'
        : days == 1
            ? 'Morgen: ${soonest.title}'
            : 'Over $days dagen: ${soonest.title}';

    // Defer until after the current frame so the Scaffold is available.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) return;
      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.event_available,
                  color: AppColors.textOnDark,
                  size: AppDimensions.iconMedium),
              const SizedBox(width: AppDimensions.spaceMedium),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textOnDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.primaryMid,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          margin: const EdgeInsets.all(AppDimensions.paddingLarge),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          ),
        ),
      );
    });
  }

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
                    _maybeShowUpcomingPopup(events);

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

  Widget _buildEventCard(BuildContext context, Event event) {
    final isUrgent = event.isWithinOneWeek;
    final isUpcoming = event.isWithinTwoWeeks;

    // Choose accent color based on urgency
    final accentColor = isUrgent
        ? AppColors.live
        : isUpcoming
            ? AppColors.primaryLight
            : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spaceLarge),
      child: GestureDetector(
        onTap: () => _showEventDetail(context, event),
        child: Stack(
          children: [
            // Main card
            Container(
              padding: const EdgeInsets.all(AppDimensions.paddingLarge),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius:
                    BorderRadius.circular(AppDimensions.radiusMedium),
                border: Border.all(
                    color: AppColors.divider, width: AppDimensions.borderThin),
                boxShadow: isUpcoming
                    ? [
                        BoxShadow(
                          color: accentColor!.withOpacity(0.18),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  // Icon with enhanced styling for upcoming events
                  Container(
                    padding: const EdgeInsets.all(AppDimensions.paddingSmall),
                    decoration: BoxDecoration(
                      color: isUpcoming
                          ? accentColor!.withOpacity(0.12)
                          : AppColors.cardBlue,
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusSmall),
                      boxShadow: isUrgent
                          ? [
                              BoxShadow(
                                color: AppColors.live.withOpacity(0.4),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(Icons.event,
                        color: isUpcoming ? accentColor : AppColors.primaryLight,
                        size: AppDimensions.iconLarge),
                  ),
                  const SizedBox(width: AppDimensions.spaceLarge),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(event.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.cardTitle.copyWith(
                                    fontWeight: isUpcoming
                                        ? FontWeight.w800
                                        : FontWeight.w700,
                                  )),
                            ),
                            if (event.isWithinTwoWeeks)
                              _buildUpcomingBadge(event),
                          ],
                        ),
                        const SizedBox(height: AppDimensions.spaceXSmall),
                        _iconRow(
                          Icons.access_time,
                          event.date,
                          isUpcoming ? accentColor : null,
                        ),
                        const SizedBox(height: 2),
                        _iconRow(Icons.location_on, event.location, null),
                        const SizedBox(height: AppDimensions.spaceSmall),
                        Text(
                          event.what,
                          style: AppTextStyles.cardSubtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spaceSmall),
                  Icon(
                    Icons.chevron_right,
                    color: isUpcoming ? accentColor : AppColors.chevronIcon,
                    size: AppDimensions.iconMedium,
                  ),
                ],
              ),
            ),
            
            // Colored accent bar on the left for upcoming events
            if (accentColor != null)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 5,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(AppDimensions.radiusMedium),
                      bottomLeft: Radius.circular(AppDimensions.radiusMedium),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Upcoming badge ──────────────────────────────────────────────────────
  //
  // - within 1 week : animated red "Bijna" with glow
  // - within 2 weeks: blue "Binnenkort"

  Widget _buildUpcomingBadge(Event event) {
    final urgent = event.isWithinOneWeek;
    final label = urgent ? 'Bijna' : 'Binnenkort';
    final color = urgent ? AppColors.live : AppColors.primaryLight;

    final badge = Container(
      margin: const EdgeInsets.only(left: AppDimensions.spaceSmall),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
        boxShadow: urgent
            ? [
                BoxShadow(
                  color: AppColors.live.withOpacity(0.5),
                  blurRadius: 8,
                  spreadRadius: 0,
                ),
              ]
            : [
                BoxShadow(
                  color: AppColors.primaryLight.withOpacity(0.3),
                  blurRadius: 4,
                  spreadRadius: 0,
                ),
              ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textOnDark,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    // Add subtle pulse animation for urgent events
    if (urgent) {
      return _PulsingBadge(child: badge);
    }
    return badge;
  }

  void _showEventDetail(BuildContext context, Event event) {
    final isUpcoming = event.isWithinTwoWeeks;
    final accentColor = event.isWithinOneWeek
        ? AppColors.live
        : isUpcoming
            ? AppColors.primaryLight
            : null;

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
              // Drag handle with accent color for upcoming events
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(
                      bottom: AppDimensions.spaceLarge),
                  decoration: BoxDecoration(
                    color: accentColor?.withOpacity(0.4) ?? AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(event.title,
                        style: AppTextStyles.screenTitleSmall),
                  ),
                  if (event.isWithinTwoWeeks) _buildUpcomingBadge(event),
                ],
              ),
              const SizedBox(height: AppDimensions.spaceLarge),
              _iconRow(
                Icons.access_time,
                event.date,
                isUpcoming ? accentColor : null,
              ),
              const SizedBox(height: AppDimensions.spaceSmall),
              _iconRow(Icons.location_on, event.location, null),
              const SizedBox(height: AppDimensions.spaceLarge),
              Text(event.what, style: AppTextStyles.cardSubtitle),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconRow(IconData icon, String label, Color? accentColor) => Row(
        children: [
          Icon(icon,
              size: AppDimensions.iconSmall,
              color: accentColor ?? AppColors.textMeta),
          const SizedBox(width: AppDimensions.spaceXSmall),
          Expanded(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.cardMeta.copyWith(
                  color: accentColor,
                  fontWeight:
                      accentColor != null ? FontWeight.w600 : FontWeight.normal,
                )),
          ),
        ],
      );
}

// ── Pulsing badge animation ─────────────────────────────────────────────────

class _PulsingBadge extends StatefulWidget {
  final Widget child;

  const _PulsingBadge({required this.child});

  @override
  State<_PulsingBadge> createState() => _PulsingBadgeState();
}

class _PulsingBadgeState extends State<_PulsingBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _animation,
      child: widget.child,
    );
  }
}