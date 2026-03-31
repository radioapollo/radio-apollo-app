/* App Date Utilities
 
   This utility class provides static helper functions for date
   and time handling used throughout the application.
 
   Features:
   - rotating/shifting lists (used for the day selector in the schedule)
   - formatting the current time for chat messages
*/
 
class AppDateUtils {
  static List<String> shiftList(List<String> list, int shift) {
    shift = shift % list.length;
    if (shift < 0) shift += list.length;
    return [...list.sublist(shift), ...list.sublist(0, shift)];
  }
 
  static String getCurrentTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }
}
