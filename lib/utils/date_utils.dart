/* App Date Utilities

   Static helper functions for date and time handling used throughout
   the application.

   Features:
   - rotating/shifting lists (used for the day selector in the schedule)
   - formatting the current time for chat messages
   - formatting a DateTime as HH:mm
   - parsing "HH:mm" time strings into minutes
   - checking whether a time range covers the current moment
   - formatting schedule times (converting "24:00" to "00:00")
   - parsing Dutch date strings for the events list
     Supports "30 mei 2026" and "30/31 mei 2026" (multi-day events)
*/

class AppDateUtils {
  // ── List helpers ──────────────────────────────────────────────────────────

  static List<String> shiftList(List<String> list, int shift) {
    shift = shift % list.length;
    if (shift < 0) shift += list.length;
    return [...list.sublist(shift), ...list.sublist(0, shift)];
  }

  // ── Time formatting ───────────────────────────────────────────────────────

  static String getCurrentTime() {
    final now = DateTime.now();
    return formatTime(now);
  }

  static String formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  // ── Schedule time helpers ─────────────────────────────────────────────────

  static String formatScheduleTime(String time) {
    if (time == '24:00') return '00:00';
    return time;
  }

  static String formatTimeRange(String start, String end) {
    if (start.isEmpty || end.isEmpty) return '--:-- - --:--';
    return '${formatScheduleTime(start)} - ${formatScheduleTime(end)}';
  }

  static int? parseTimeToMinutes(String time) {
    if (time.isEmpty) return null;
    final parts = time.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  static bool isCurrentTimeInRange(String startTime, String endTime) {
    final start = parseTimeToMinutes(startTime);
    final end = parseTimeToMinutes(endTime);
    if (start == null || end == null) return false;

    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;

    if (end <= start) {
      return currentMinutes >= start || currentMinutes < end;
    }

    return currentMinutes >= start && currentMinutes < end;
  }

  // ── Dutch date parsing ────────────────────────────────────────────────────

  static const _dutchMonths = {
    'januari': 1,
    'februari': 2,
    'maart': 3,
    'april': 4,
    'mei': 5,
    'juni': 6,
    'juli': 7,
    'augustus': 8,
    'september': 9,
    'oktober': 10,
    'november': 11,
    'december': 12,
  };

  static DateTime? parseDutchDate(String input) {
    final parts = input.trim().toLowerCase().split(RegExp(r'\s+'));
    if (parts.length != 3) return null;

    final dayRaw = parts[0].split(RegExp(r'[/\-]')).first;
    final day = int.tryParse(dayRaw);
    final month = _dutchMonths[parts[1]];
    final year = int.tryParse(parts[2]);

    if (day == null || month == null || year == null) return null;
    return DateTime(year, month, day);
  }
}
