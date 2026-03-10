/* Program Service

   This service manages the radio program schedule.

   It can:
   - store program data
   - retrieve schedules
   - provide program information to the UI
*/

import '../utils/date_utils.dart';

class ProgramService {

  static int getWeekdayFromName(String day) {
    switch (day) {
      case "Monday":
        return 1;
      case "Tuesday":
        return 2;
      case "Wednesday":
        return 3;
      case "Thursday":
        return 4;
      case "Friday":
        return 5;
      case "Saturday":
        return 6;
      case "Sunday":
        return 7;
      default:
        return DateTime.now().weekday;
    }
  }

  // Weekday names
  static const List<String> weekdays = [
    "Monday",
    "Tuesday",
    "Wednesday",
    "Thursday",
    "Friday",
    "Saturday",
    "Sunday"
  ];

  // Programs per day
  static List<Map<String, String>> getProgramsForDay(int weekday) {
    switch (weekday) {
      case 1:
        return [
          {"time": "06:00", "title": "Monday Morning", "desc": "Start the week with energy"},
          {"time": "10:00", "title": "Apollo Hits", "desc": "The best hits of today"},
          {"time": "14:00", "title": "Relax Mix", "desc": "Afternoon chill music"},
        ];

      case 2:
        return [
          {"time": "06:00", "title": "Wake Up Apollo", "desc": "Good vibes to start Tuesday"},
          {"time": "10:00", "title": "Throwback Tuesday", "desc": "Best classics"},
          {"time": "14:00", "title": "Pop Mix", "desc": "Popular hits"},
        ];

      case 3:
        return [
          {"time": "06:00", "title": "Midweek Energy", "desc": "Power through the week"},
          {"time": "10:00", "title": "Top 40", "desc": "Top chart music"},
          {"time": "14:00", "title": "Chill Radio", "desc": "Relax and listen"},
        ];

      case 4:
        return [
          {"time": "06:00", "title": "Morning Boost", "desc": "Start Thursday right"},
          {"time": "10:00", "title": "Retro Thursday", "desc": "80s and 90s hits"},
          {"time": "14:00", "title": "Summer Vibes", "desc": "Feel the sunshine"},
        ];

      case 5:
        return [
          {"time": "06:00", "title": "Friday Wake Up", "desc": "The weekend is coming"},
          {"time": "10:00", "title": "Weekend Warmup", "desc": "Party vibes"},
          {"time": "14:00", "title": "Happy Hour", "desc": "Music for your Friday"},
        ];

      case 6:
        return [
          {"time": "08:00", "title": "Weekend Start", "desc": "Easy Saturday morning"},
          {"time": "12:00", "title": "Dance Mix", "desc": "Best dance music"},
          {"time": "18:00", "title": "Saturday Party", "desc": "Party all night"},
        ];

      case 7:
        return [
          {"time": "08:00", "title": "Sunday Chill", "desc": "Relaxing Sunday vibes"},
          {"time": "12:00", "title": "Acoustic Sunday", "desc": "Soft acoustic music"},
          {"time": "18:00", "title": "Sunday Night", "desc": "End the weekend calmly"},
        ];

      default:
        return [];
    }
  }

  // Returns the weekday list shifted so today appears in the center
  List<String> getShiftedDays(int selectedIndex) {
    final today = DateTime.now().weekday;
    final shift = today - (selectedIndex + 1);
    return AppDateUtils.shiftList(List.from(weekdays), shift);
  }
}