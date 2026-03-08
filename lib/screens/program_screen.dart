/* Program Schedule Screen

  This screen displays the radio station's program schedule.

   Users can:
   - view the programs for different days
   - scroll through the list of shows
*/

import 'package:flutter/material.dart';
import '../services/program_service.dart';
import '../widgets/page_with_header.dart';
import '../widgets/program_card.dart';
import '../widgets/day_selector.dart';

class ProgramScreen extends StatefulWidget {
  const ProgramScreen({super.key});

  @override
  State<ProgramScreen> createState() => _ProgramScreenState();
}

class _ProgramScreenState extends State<ProgramScreen> {
  late final ProgramService _programService;
  late List<String> _days;
  int _selectedIndex = 3;

  @override
  void initState() {
    super.initState();
    _programService = ProgramService();
    _days = _programService.getShiftedDays(_selectedIndex);
  }

  @override
  Widget build(BuildContext context) {
    return PageWithHeader(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Programma",
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 20),
          DaySelector(
            days: _days,
            selectedIndex: _selectedIndex,
            onDaySelected: _onDaySelected,
          ),
          const SizedBox(height: 25),
          ..._programService.programs.map((program) => ProgramCard(
                time: program.time,
                title: program.title,
                subtitle: program.subtitle,
              )),
        ],
      ),
    );
  }

  void _onDaySelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }
}