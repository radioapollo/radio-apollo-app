/* App Date Utilities

   This utility class provides helper functions related to date
   and time handling used throughout the application.

   The methods in this class are static, meaning they can be called
   without creating an instance of the class.

   Current features include:
   - rotating lists (used for shifting days in the schedule)
   - formatting the current time for chat messages
*/

class AppDateUtils {
  static List<String> shiftList(List<String> list, int shift) {
    List<String> result = List.from(list);
    while (shift < 0) {
      shift += list.length;
    }
    for (int i = 0; i < shift; i++) {
      result.add(result.removeAt(0));
    }
    return result;
  }

  static String getCurrentTime() {
    final now = DateTime.now();
    return "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
  }
}