/* Calendar Utilities

   Helpers for adding an Event to the user's device calendar via the
   `add_2_calendar` package.

   Events in the app don't carry a start/end time — only a Dutch date
   string (e.g. "30 mei 2026" or the multi-day form "30/31 mei 2026").
   We therefore create all-day calendar entries:

   - single day  → one all-day entry on that date
   - multi-day   → all-day entry spanning [day, lastDay] inclusive

   The `add_2_calendar` package wants exclusive end dates for all-day
   events on Android (see its README), so for a multi-day "30/31 mei"
   we pass start = 30 mei 00:00 and end = 1 jun 00:00.

   The package also ships a class called `Event`, which collides with
   our own model. We import it with the `a2c` prefix to keep things
   readable.
*/

import 'package:add_2_calendar/add_2_calendar.dart' as a2c;
import '../models/event.dart';
import 'date_utils.dart';

class CalendarUtils {
  CalendarUtils._();

  static Future<bool> addEventToCalendar(Event event) async {
    final entry = _buildCalendarEntry(event);
    if (entry == null) return false;
    return a2c.Add2Calendar.addEvent2Cal(entry);
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  static a2c.Event? _buildCalendarEntry(Event event) {
    final start = AppDateUtils.parseDutchDate(event.date);
    if (start == null) return null;

    final lastDay = _parseMultiDayLastDay(event.date, start);
    final end = (lastDay ?? start).add(const Duration(days: 1));

    return a2c.Event(
      title: event.title,
      description: event.what,
      location: event.location,
      startDate: start,
      endDate: end,
      allDay: true,
    );
  }

  static DateTime? _parseMultiDayLastDay(String input, DateTime start) {
    final parts = input.trim().toLowerCase().split(RegExp(r'\s+'));
    if (parts.length != 3) return null;

    final dayParts = parts[0].split(RegExp(r'[/\-]'));
    if (dayParts.length < 2) return null;

    final lastDay = int.tryParse(dayParts.last);
    if (lastDay == null) return null;

    return DateTime(start.year, start.month, lastDay);
  }
}