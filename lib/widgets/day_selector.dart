/* Day Selector Widget

   This widget displays a horizontal list of days
   used in the program schedule screen.

   Users can select a day to view the radio programs
   scheduled for that specific day.
*/

import 'package:flutter/material.dart';

class DaySelector extends StatelessWidget {
  final List<String> days;
  final int selectedIndex;
  final Function(int) onDaySelected;

  const DaySelector({
    super.key,
    required this.days,
    required this.selectedIndex,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 55,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final active = index == selectedIndex;
          return GestureDetector(
            onTap: () => onDaySelected(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: active ? Colors.white : Colors.white12,
                borderRadius: BorderRadius.circular(50),
                border: Border.all(
                  color: active ? Colors.white : Colors.white30,
                  width: 1.2,
                ),
              ),
              child: Center(
                child: Text(
                  days[index],
                  style: TextStyle(
                    color: active ? Colors.black : Colors.white,
                    fontWeight: active ? FontWeight.bold : FontWeight.w400,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}