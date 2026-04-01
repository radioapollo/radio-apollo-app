/* Program Screen

   This screen shows the weekly radio program schedule.

   It includes:
   - a day selector to switch between days
   - a list of programs for the selected day
*/

import 'package:flutter/material.dart';
import '../services/program_service.dart';
import '../widgets/page_with_header.dart';
import '../widgets/program_card.dart';
import '../widgets/day_selector.dart';
import '../theme/app_theme.dart';

class ProgramScreen extends StatefulWidget {
  const ProgramScreen({super.key});

  @override
  State<ProgramScreen> createState() => _ProgramScreenState();
}

class _ProgramScreenState extends State<ProgramScreen> {
  final _programService = ProgramService();
  late List<String> _days;
  int _selectedIndex = 3;

  @override
  void initState() {
    super.initState();
    _days = _programService.getShiftedDays(_selectedIndex);
  }

  @override
  Widget build(BuildContext context) {
    final weekday  = ProgramService.getWeekdayFromName(_days[_selectedIndex]);
    final programs = ProgramService.getProgramsForDay(weekday);

    return PageWithHeader(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Programma', style: AppTextStyles.screenTitle),
          const SizedBox(height: AppDimensions.paddingXLarge),
          DaySelector(
            days: _days,
            selectedIndex: _selectedIndex,
            onDaySelected: (i) => setState(() => _selectedIndex = i),
          ),
          const SizedBox(height: AppDimensions.space25),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: programs.length,
            itemBuilder: (context, index) {
              final p = programs[index];
              return ProgramCard(
                time: p['time']!,
                title: p['title']!,
                subtitle: p['desc']!,
                border: Border.all(
                    color: Colors.white24,
                    width: AppDimensions.borderThin),
              );
            },
          ),
        ],
      ),
    );
  }
}