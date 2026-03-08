/* Program Service

   This service manages the radio program schedule.

   It can:
   - store program data
   - retrieve schedules
   - provide program information to the UI
*/

import '../models/program.dart';
import '../utils/date_utils.dart';

class ProgramService {
  final List<String> weekDays = ["Ma", "Di", "Wo", "Do", "Vr", "Za", "Zo"];
  
  final List<Program> programs = const [
    Program(
      time: "06:00 - 10:00",
      title: "Apollo Ochtendshow",
      subtitle: "Start je dag met nieuws, muziek & fun",
    ),
    Program(
      time: "10:00 - 12:00",
      title: "Hits & Classics",
      subtitle: "De beste 80s 90s & hedendaagse hits",
    ),
    Program(
      time: "12:00 - 14:00",
      title: "Lunch Break Live",
      subtitle: "Gezellige middagsfeer met klassiekers",
    ),
    Program(
      time: "18:00 - 20:00",
      title: "Drive Home",
      subtitle: "Verkeersinfo, hits en sfeer",
    ),
  ];

  List<String> getShiftedDays(int selectedIndex) {
    final today = DateTime.now().weekday;
    final shift = today - (selectedIndex + 1);
    return AppDateUtils.shiftList(List.from(weekDays), shift);
  }
}