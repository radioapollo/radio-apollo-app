/* Event Model

   This file defines the structure of an event.

   It contains:
   - the title of the event
   - the date it takes place (raw Dutch string, same as original)
   - the location of the event
   - a description of what the event is about
   - an optional image URL shown in the event list and detail sheet
   - helper getters to know whether the event is upcoming and how close it is
*/

import '../utils/date_utils.dart';

class Event {
  final String title;
  final String date;
  final String location;
  final String what;
  final String? imageUrl;

  const Event({
    required this.title,
    required this.date,
    required this.location,
    required this.what,
    this.imageUrl,
  });

  /// True when a usable image URL is present.
  /// Checks that the string is non-null and non-empty after trimming —
  /// Firestore sometimes stores empty strings rather than missing fields.
  bool get hasImage => imageUrl != null && imageUrl!.trim().isNotEmpty;

  /// Parsed DateTime from the Dutch date string. Null if parsing fails.
  DateTime? get parsedDate => AppDateUtils.parseDutchDate(date);

  /// Number of full days between today (at midnight) and the event date.
  int? get daysUntil {
    final d = parsedDate;
    if (d == null) return null;
    final today = DateTime.now();
    final eventDay = DateTime(d.year, d.month, d.day);
    final nowDay = DateTime(today.year, today.month, today.day);
    return eventDay.difference(nowDay).inDays;
  }

  /// True when the event is within the next 7 days (today included).
  bool get isWithinOneWeek {
    final n = daysUntil;
    return n != null && n >= 0 && n <= 7;
  }

  /// True when the event is within the next 14 days (today included).
  bool get isWithinTwoWeeks {
    final n = daysUntil;
    return n != null && n >= 0 && n <= 14;
  }
}
