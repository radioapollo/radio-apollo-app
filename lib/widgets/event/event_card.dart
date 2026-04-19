/* Event Card Widget

   A single event in the event list.

   It shows:
   - an icon (glowing red when urgent, accented when upcoming)
   - the event title, date, location, and a 2-line description
   - an UpcomingBadge when the event is within two weeks
   - a colored accent bar on the left for upcoming events
   - a chevron to indicate the card is tappable

   Tapping the card calls [onTap] so the parent can open the detail sheet.
*/

import 'package:flutter/material.dart';
import '../../models/event.dart';
import '../../theme/app_theme.dart';
import 'event_icon_row.dart';
import 'upcoming_badge.dart';

class EventCard extends StatelessWidget {
  final Event        event;
  final VoidCallback onTap;

  const EventCard({
    super.key,
    required this.event,
    required this.onTap,
  });

  Color? get _accentColor {
    if (event.isWithinOneWeek)  return AppColors.live;
    if (event.isWithinTwoWeeks) return AppColors.primaryLight;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isUrgent   = event.isWithinOneWeek;
    final isUpcoming = event.isWithinTwoWeeks;
    final accent     = _accentColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spaceLarge),
      child: GestureDetector(
        onTap: onTap,
        child: _buildCard(
          context,
          isUrgent:   isUrgent,
          isUpcoming: isUpcoming,
          accent:     accent,
        ),
      ),
    );
  }

  // ── Main card body ────────────────────────────────────────────────────────

  Widget _buildCard(
    BuildContext context, {
    required bool   isUrgent,
    required bool   isUpcoming,
    required Color? accent,
  }) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color:        AppColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(
            color: AppColors.divider, width: AppDimensions.borderThin),
        boxShadow: isUpcoming && accent != null
            ? [
                BoxShadow(
                  color:     accent.withValues(alpha: 0.18),
                  blurRadius: 12,
                  offset:     const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingLarge),
            child: Row(
              children: [
                _buildIcon(isUrgent: isUrgent, isUpcoming: isUpcoming, accent: accent),
                const SizedBox(width: AppDimensions.spaceLarge),
                Expanded(child: _buildInfo(isUpcoming: isUpcoming, accent: accent)),
                const SizedBox(width: AppDimensions.spaceSmall),
                Icon(
                  Icons.chevron_right,
                  color: isUpcoming ? accent : AppColors.chevronIcon,
                  size:  AppDimensions.iconMedium,
                ),
              ],
            ),
          ),
          if (accent != null) _buildAccentBar(accent),
        ],
      ),
    );
  }

  // ── Leading icon ──────────────────────────────────────────────────────────

  Widget _buildIcon({
    required bool   isUrgent,
    required bool   isUpcoming,
    required Color? accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingSmall),
      decoration: BoxDecoration(
        color: isUpcoming && accent != null
            ? accent.withValues(alpha: 0.12)
            : AppColors.cardBlue,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
        boxShadow: isUrgent
            ? [
                BoxShadow(
                  color: AppColors.live.withValues(alpha: 0.4),
                  blurRadius:  12,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Icon(
        Icons.event,
        color: isUpcoming ? accent : AppColors.primaryLight,
        size:  AppDimensions.iconLarge,
      ),
    );
  }

  // ── Info column ───────────────────────────────────────────────────────────

  Widget _buildInfo({required bool isUpcoming, required Color? accent}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize:       MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                event.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.cardTitle.copyWith(
                  fontWeight:
                      isUpcoming ? FontWeight.w800 : FontWeight.w700,
                ),
              ),
            ),
            if (event.isWithinTwoWeeks) UpcomingBadge(event: event),
          ],
        ),
        const SizedBox(height: AppDimensions.spaceXSmall),
        EventIconRow(
          icon:   Icons.access_time,
          label:  event.date,
          accent: isUpcoming ? accent : null,
        ),
        const SizedBox(height: 2),
        EventIconRow(icon: Icons.location_on, label: event.location),
        const SizedBox(height: AppDimensions.spaceSmall),
        Text(
          event.what,
          style:    AppTextStyles.cardSubtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  // ── Accent bar on the left edge ───────────────────────────────────────────

  Widget _buildAccentBar(Color accent) {
    return Positioned(
      left:   0,
      top:    0,
      bottom: 0,
      child: Container(
        width: 5,
        decoration: BoxDecoration(
          color: accent,
          borderRadius: const BorderRadius.only(
            topLeft:    Radius.circular(AppDimensions.radiusMedium),
            bottomLeft: Radius.circular(AppDimensions.radiusMedium),
          ),
        ),
      ),
    );
  }
}