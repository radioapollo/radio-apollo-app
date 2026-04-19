/* Upcoming Event Snackbar

   Shows a floating snackbar announcing the soonest upcoming event
   when there is at least one event within the next two weeks.

   The snackbar is a one-shot per app session: a static flag prevents
   it from being shown more than once, so tab switches do not re-trigger
   it. The flag resets when the app is restarted.
*/

import 'package:flutter/material.dart';
import '../../models/event.dart';
import '../../theme/app_theme.dart';

class UpcomingEventSnackbar {
  UpcomingEventSnackbar._();

  static bool _shownThisSession = false;

  /// Shows the snackbar if [events] contains at least one upcoming event
  /// and the snackbar has not been shown yet this session.
  static void maybeShow(BuildContext context, List<Event> events) {
    if (_shownThisSession) return;

    final soonest = _findSoonest(events);
    if (soonest == null) return;

    _shownThisSession = true;

    // Defer until after the current frame so the Scaffold is available.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) return;
      messenger.showSnackBar(_buildSnackbar(soonest));
    });
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static Event? _findSoonest(List<Event> events) {
    Event? soonest;
    for (final e in events) {
      if (!e.isWithinTwoWeeks) continue;
      if (soonest == null ||
          (e.daysUntil ?? 999) < (soonest.daysUntil ?? 999)) {
        soonest = e;
      }
    }
    return soonest;
  }

  static String _labelFor(Event event) {
    final days = event.daysUntil ?? 0;
    if (days == 0) return 'Vandaag: ${event.title}';
    if (days == 1) return 'Morgen: ${event.title}';
    return 'Over $days dagen: ${event.title}';
  }

  static SnackBar _buildSnackbar(Event event) {
    return SnackBar(
      content: Row(
        children: [
          const Icon(Icons.event_available,
              color: AppColors.textOnDark,
              size:  AppDimensions.iconMedium),
          const SizedBox(width: AppDimensions.spaceMedium),
          Expanded(
            child: Text(
              _labelFor(event),
              style: const TextStyle(
                color:      AppColors.textOnDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: AppColors.primaryMid,
      behavior:        SnackBarBehavior.floating,
      duration:        const Duration(seconds: 4),
      margin:          const EdgeInsets.all(AppDimensions.paddingLarge),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      ),
    );
  }
}