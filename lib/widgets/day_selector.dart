/* Day Selector Widget

   This widget displays a horizontal scrollable list of days
   used in the program schedule screen.

   Users can select a day to view the radio programs
   scheduled for that specific day. The selected day is
   automatically scrolled into the center of the screen.
*/

import 'package:flutter/material.dart';

class DaySelector extends StatefulWidget {
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
  State<DaySelector> createState() => _DaySelectorState();
}

class _DaySelectorState extends State<DaySelector> {
  final _scrollController = ScrollController();

  static const _itemWidth = 110.0;
  static const _spacing = 12.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
  }

  @override
  void didUpdateWidget(covariant DaySelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scrollToSelected();
  }

  void _scrollToSelected() {
    final screenWidth = MediaQuery.of(context).size.width;
    final offset = (widget.selectedIndex * (_itemWidth + _spacing))
        - (screenWidth / 2)
        + (_itemWidth / 2);

    _scrollController.animateTo(
      offset.clamp(0, double.infinity),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        itemCount: widget.days.length,
        itemBuilder: (context, index) {
          final isSelected = index == widget.selectedIndex;
          return Padding(
            padding: const EdgeInsets.only(right: _spacing),
            child: GestureDetector(
              onTap: () => widget.onDaySelected(index),
              child: Container(
                width: _itemWidth,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF3A5F8A)
                      : const Color(0xFF2C4A6A),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  widget.days[index],
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
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