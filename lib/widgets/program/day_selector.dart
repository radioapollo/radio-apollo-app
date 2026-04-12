/* Day Selector Widget

   This widget displays a horizontal scrollable list of days
   used in the program schedule screen.

   Users can select a day to view the radio programs
   scheduled for that specific day. The selected day is
   automatically scrolled into the center of the screen.
*/

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
  }

  @override
  void didUpdateWidget(covariant DaySelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSelected() {
    if (!_scrollController.hasClients ||
        !_scrollController.position.hasContentDimensions) return;

    final screenWidth = MediaQuery.of(context).size.width;
    final offset =
        (widget.selectedIndex *
                (AppDimensions.daySelectorItemWidth +
                    AppDimensions.daySelectorSpacing)) -
            (screenWidth / 2) +
            (AppDimensions.daySelectorItemWidth / 2);

    _scrollController.animateTo(
      offset.clamp(0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppDimensions.daySelectorHeight,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        itemCount: widget.days.length,
        itemBuilder: (context, index) {
          final isSelected = index == widget.selectedIndex;
          return Padding(
            padding: const EdgeInsets.only(
                right: AppDimensions.daySelectorSpacing),
            child: GestureDetector(
              onTap: () => widget.onDaySelected(index),
              child: Container(
                width: AppDimensions.daySelectorItemWidth,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.steelLight
                      : AppColors.steelMedium,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusPill),
                ),
                child: Text(widget.days[index],
                    style: AppTextStyles.dayLabel),
              ),
            ),
          );
        },
      ),
    );
  }
}