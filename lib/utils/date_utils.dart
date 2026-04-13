/* App Date Utilities

   This utility class provides static helper functions for date
   and time handling used throughout the application.

   Features:
   - rotating/shifting lists (used for the day selector in the schedule)
   - formatting the current time for chat messages
   - formatting a DateTime as HH:mm (used when converting Firestore timestamps)
   - parsing "HH:mm" time strings into minutes (used for current-program detection)
   - checking whether a time range covers the current moment
   - formatting schedule times (converting "24:00" to "00:00")
*/

class AppDateUtils {
  static List<String> shiftList(List<String> list, int shift) {
    shift = shift % list.length;
    if (shift < 0) shift += list.length;
    return [...list.sublist(shift), ...list.sublist(0, shift)];
  }

  /// Returns the current time as a HH:mm string (e.g. "14:05").
  static String getCurrentTime() {
    final now = DateTime.now();
    return formatTime(now);
  }

  /// Formats any [DateTime] as a HH:mm string (e.g. "09:07").
  static String formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  // ── Schedule time helpers ─────────────────────────────────────────────────

  /// Normalises a schedule time string: converts "24:00" → "00:00".
  static String formatScheduleTime(String time) {
    if (time == '24:00') return '00:00';
    return time;
  }

  /// Formats a start–end pair into a display string like "08:00 - 10:00".
  static String formatTimeRange(String start, String end) {
    return '${formatScheduleTime(start)} - ${formatScheduleTime(end)}';
  }

  /// Parses a "HH:mm" string into total minutes since midnight.
  static int parseTimeToMinutes(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  /// Returns true when the current moment falls inside [startTime]–[endTime].
  /// Handles overnight ranges (e.g. 23:00 – 02:00).
  static bool isCurrentTimeInRange(String startTime, String endTime) {
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;

    final start = parseTimeToMinutes(startTime);
    final end = parseTimeToMinutes(endTime);

    if (end <= start) {
      // Overnight range
      return currentMinutes >= start || currentMinutes < end;
    }

    return currentMinutes >= start && currentMinutes < end;
  }

  static const _dutchMonths = {
  'januari': 1, 'februari': 2, 'maart': 3, 'april': 4,
  'mei': 5, 'juni': 6, 'juli': 7, 'augustus': 8,
  'september': 9, 'oktober': 10, 'november': 11, 'december': 12,
};

  /// Parses a Dutch date string like "1 mei 2026" into a DateTime.
  /// Returns null if the string can't be parsed (e.g. "to be announced").
  static DateTime? parseDutchDate(String dateStr) {
    final parts = dateStr.toLowerCase().split(' ');
    if (parts.length != 3) return null;

    // Handle "30/31" style — take the first day
    final dayStr = parts[0].contains('/') ? parts[0].split('/')[0] : parts[0];
    final day = int.tryParse(dayStr);
    final month = _dutchMonths[parts[1]];
    final year = int.tryParse(parts[2]);

    if (day == null || month == null || year == null) return null;
    return DateTime(year, month, day);
  }
}