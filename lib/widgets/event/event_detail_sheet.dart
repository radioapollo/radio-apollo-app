/* Event Detail Sheet

   A draggable modal bottom sheet shown when an event card is tapped.

   It shows the full event title, date, location, and description —
   without the truncation applied in the list view.

   When the event has an imageUrl, a full-width banner is rendered at
   the top of the sheet. The banner fails silently (hides itself) if
   the image can't be loaded.

   Accent color tiers (must stay in sync with EventCard):
   - today           → green
   - within 1 week   → red
   - within 2 weeks  → blue
   - further out     → no accent
*/

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/event.dart';
import '../../theme/app_theme.dart';
import 'event_icon_row.dart';
import 'upcoming_badge.dart';
import 'add_to_calendar_button.dart';

class EventDetailSheet extends StatelessWidget {
  final Event event;

  const EventDetailSheet({super.key, required this.event});

  static Future<void> show(BuildContext context, Event event) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusXLarge),
        ),
      ),
      builder: (_) => EventDetailSheet(event: event),
    );
  }

  bool get _isToday => event.daysUntil == 0;

  Color? get _accentColor {
    if (_isToday) return AppColors.nowPlayingDot;
    if (event.isWithinOneWeek) return AppColors.live;
    if (event.isWithinTwoWeeks) return AppColors.primaryLight;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isUpcoming = event.isWithinTwoWeeks;
    final accent = _accentColor;

    return DraggableScrollableSheet(
      initialChildSize: event.hasImage ? 0.55 : 0.4,
      minChildSize: 0.25,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => SingleChildScrollView(
        controller: scrollController,

        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (event.hasImage) _buildImageBanner(),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.paddingXLarge,
                AppDimensions.paddingXLarge,
                AppDimensions.paddingXLarge,
                AppDimensions.space30,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!event.hasImage) _buildDragHandle(accent),
                  _buildTitle(),
                  const SizedBox(height: AppDimensions.spaceLarge),
                  EventIconRow(
                    icon: Icons.access_time,
                    label: event.date,
                    accent: isUpcoming ? accent : null,
                  ),
                  const SizedBox(height: AppDimensions.spaceSmall),
                  EventIconRow(icon: Icons.location_on, label: event.location),
                  const SizedBox(height: AppDimensions.spaceLarge),
                  Text(event.what, style: AppTextStyles.cardSubtitle),
                  const SizedBox(height: AppDimensions.spaceXLarge),
                  AddToCalendarButton(event: event),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Banner image ──────────────────────────────────────────────────────────

  Widget _buildImageBanner() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppDimensions.radiusXLarge),
      ),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: CachedNetworkImage(
          imageUrl: event.imageUrl!,
          fit: BoxFit.cover,
          placeholder: (_, _) => Container(color: AppColors.cardBlue),

          errorWidget: (_, _, _) => const SizedBox.shrink(),
        ),
      ),
    );
  }

  // ── Drag handle ───────────────────────────────────────────────────────────

  Widget _buildDragHandle(Color? accent) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(bottom: AppDimensions.spaceLarge),
        decoration: BoxDecoration(
          color: accent?.withValues(alpha: 0.4) ?? AppColors.divider,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  // ── Title + upcoming badge ────────────────────────────────────────────────

  Widget _buildTitle() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(event.title, style: AppTextStyles.screenTitleSmall),
        ),
        if (event.isWithinTwoWeeks) UpcomingBadge(event: event),
      ],
    );
  }
}
