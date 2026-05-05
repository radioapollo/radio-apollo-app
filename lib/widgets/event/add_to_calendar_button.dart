/* Add To Calendar Button

   A small action button shown at the bottom of the event detail sheet.
   Tapping it opens the OS calendar with a pre-filled all-day event
   matching the event's title, location, and description.

   Failure paths:
   - Date can't be parsed → CalendarUtils returns false. We show a
     small snackbar explaining the calendar entry couldn't be created.
   - The OS calendar UI never opens (rare, e.g. no calendar app
     installed on Android) → also handled by the false return.
*/

import 'package:flutter/material.dart';
import '../../models/event.dart';
import '../../theme/app_theme.dart';
import '../../utils/calendar_utils.dart';

class AddToCalendarButton extends StatelessWidget {
  final Event event;

  const AddToCalendarButton({super.key, required this.event});

  Future<void> _onTap(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await CalendarUtils.addEventToCalendar(event);
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Kon dit evenement niet aan de agenda toevoegen.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _onTap(context),
        icon: const Icon(
          Icons.event_available,
          color: AppColors.primaryLight,
          size: 20,
        ),
        label: const Text(
          'Toevoegen aan agenda',
          style: TextStyle(
            color: AppColors.primaryLight,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            vertical: AppDimensions.paddingMedium,
          ),
          side: const BorderSide(
            color: AppColors.primaryLight,
            width: AppDimensions.borderThin,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          ),
        ),
      ),
    );
  }
}