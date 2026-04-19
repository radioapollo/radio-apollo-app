/* Event Detail Sheet

   A draggable modal bottom sheet shown when an event card is tapped.

   It shows the full event title, date, location, and description —
   without the truncation applied in the list view.
*/

import 'package:flutter/material.dart';
import '../../models/event.dart';
import '../../theme/app_theme.dart';
import 'event_icon_row.dart';
import 'upcoming_badge.dart';

class EventDetailSheet extends StatelessWidget {
  final Event event;

  const EventDetailSheet({super.key, required this.event});

  /// Convenience to show the sheet as a modal.
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

  Color? get _accentColor {
    if (event.isWithinOneWeek) return AppColors.live;
    if (event.isWithinTwoWeeks) return AppColors.primaryLight;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isUpcoming = event.isWithinTwoWeeks;
    final accent = _accentColor;

    return DraggableScrollableSheet(
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
            _buildDragHandle(accent),
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
          ],
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

  // ── Title row with optional badge ─────────────────────────────────────────

  Widget _buildTitle() {
    return Row(
      children: [
        Expanded(
          child: Text(event.title, style: AppTextStyles.screenTitleSmall),
        ),
        if (event.isWithinTwoWeeks) UpcomingBadge(event: event),
      ],
    );
  }
}
