/* Day Selector Widget

   A horizontally-scrollable row of day pills used on the program
   screen to switch between weekdays in the schedule.

   Items size themselves to their text content (intrinsic width)
   so longer day names like "Donderdag" or "Zaterdag" never clip,
   regardless of screen width. The row scrolls horizontally and
   auto-centers on the selected day when the selection changes.
*/

import 'dart:async';
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
  Timer? _scrollDebounce;

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
    _scrollDebounce?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Auto-scroll to selected day ───────────────────────────────────────────

  void _scrollToSelected() {
    _scrollDebounce?.cancel();

    _scrollDebounce = Timer(const Duration(milliseconds: 50), () {
      if (!_scrollController.hasClients ||
          !_scrollController.position.hasContentDimensions) {
        return;
      }

      final screenWidth = MediaQuery.of(context).size.width;

      const estimatedItemWidth = 90.0;
      final offset =
          (widget.selectedIndex *
              (estimatedItemWidth + AppDimensions.daySelectorSpacing)) -
          (screenWidth / 2) +
          (estimatedItemWidth / 2);

      _scrollController.animateTo(
        offset.clamp(0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

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
              right: AppDimensions.daySelectorSpacing,
            ),
            child: GestureDetector(
              onTap: () => widget.onDaySelected(index),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 0,
                ),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.steelLight
                      : AppColors.steelMedium,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                ),
                child: Text(
                  widget.days[index],
                  style: AppTextStyles.dayLabel,
                  softWrap: false,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
