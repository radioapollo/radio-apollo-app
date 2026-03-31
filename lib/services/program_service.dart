/* Program Service

   This service manages the radio program schedule.

   It handles:
   - providing program data per weekday
   - returning a shifted day list so today is centered in the selector
*/

import '../utils/date_utils.dart';

class ProgramService {
  static const List<String> weekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    'Friday', 'Saturday', 'Sunday',
  ];

  static int getWeekdayFromName(String day) =>
      weekdays.indexOf(day) + 1 == 0
          ? DateTime.now().weekday
          : weekdays.indexOf(day) + 1;

  static List<Map<String, String>> getProgramsForDay(int weekday) {
    const schedule = {
      1: [
        {'time': '06:00', 'title': 'Monday Morning',   'desc': 'Start the week with energy'},
        {'time': '10:00', 'title': 'Apollo Hits',       'desc': 'The best hits of today'},
        {'time': '14:00', 'title': 'Relax Mix',         'desc': 'Afternoon chill music'},
      ],
      2: [
        {'time': '06:00', 'title': 'Wake Up Apollo',    'desc': 'Good vibes to start Tuesday'},
        {'time': '10:00', 'title': 'Throwback Tuesday', 'desc': 'Best classics'},
        {'time': '14:00', 'title': 'Pop Mix',           'desc': 'Popular hits'},
      ],
      3: [
        {'time': '06:00', 'title': 'Midweek Energy',    'desc': 'Power through the week'},
        {'time': '10:00', 'title': 'Top 40',            'desc': 'Top chart music'},
        {'time': '14:00', 'title': 'Chill Radio',       'desc': 'Relax and listen'},
      ],
      4: [
        {'time': '06:00', 'title': 'Morning Boost',     'desc': 'Start Thursday right'},
        {'time': '10:00', 'title': 'Retro Thursday',    'desc': '80s and 90s hits'},
        {'time': '14:00', 'title': 'Summer Vibes',      'desc': 'Feel the sunshine'},
      ],
      5: [
        {'time': '06:00', 'title': 'Friday Wake Up',    'desc': 'The weekend is coming'},
        {'time': '10:00', 'title': 'Weekend Warmup',    'desc': 'Party vibes'},
        {'time': '14:00', 'title': 'Happy Hour',        'desc': 'Music for your Friday'},
      ],
      6: [
        {'time': '08:00', 'title': 'Weekend Start',     'desc': 'Easy Saturday morning'},
        {'time': '12:00', 'title': 'Dance Mix',         'desc': 'Best dance music'},
        {'time': '18:00', 'title': 'Saturday Party',    'desc': 'Party all night'},
      ],
      7: [
        {'time': '08:00', 'title': 'Sunday Chill',      'desc': 'Relaxing Sunday vibes'},
        {'time': '12:00', 'title': 'Acoustic Sunday',   'desc': 'Soft acoustic music'},
        {'time': '18:00', 'title': 'Sunday Night',      'desc': 'End the weekend calmly'},
      ],
    };
    return List<Map<String, String>>.from(schedule[weekday] ?? []);
  }

  List<String> getShiftedDays(int selectedIndex) {
    final shift = DateTime.now().weekday - (selectedIndex + 1);
    return AppDateUtils.shiftList(List.from(weekdays), shift);
  }
}