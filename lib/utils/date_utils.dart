/* App Date Utilities

   This utility class provides static helper functions for date
   and time handling used throughout the application.

   Features:
   - rotating/shifting lists (used for the day selector in the schedule)
   - formatting the current time for chat messages
   - formatting a DateTime as HH:mm (used when converting Firestore timestamps)
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
}