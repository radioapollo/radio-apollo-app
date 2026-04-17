/* Day Selector Widget

   FIXES APPLIED:
   - Day labels no longer clip on smaller screens or with longer day names.
     Items now size themselves to their text content (intrinsic width)
     instead of using a fixed AppDimensions.daySelectorItemWidth.
     The row remains horizontally scrollable.
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

    // FIX: Use a generous estimated item width for scroll calculation.
    // The actual render width is intrinsic so we can't know it exactly,
    // but estimating from the longest day name keeps the centering close.
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
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppDimensions.daySelectorHeight,
      child: ListView.builder(
        controller:     _scrollController,
        scrollDirection: Axis.horizontal,
        itemCount:      widget.days.length,
        itemBuilder: (context, index) {
          final isSelected = index == widget.selectedIndex;
          return Padding(
            padding: const EdgeInsets.only(
                right: AppDimensions.daySelectorSpacing),
            child: GestureDetector(
              onTap: () => widget.onDaySelected(index),
              child: Container(
                // FIX: Remove fixed width — let the container size to its content.
                // This prevents text clipping on smaller screens or longer labels.
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 0),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.steelLight
                      : AppColors.steelMedium,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusPill),
                ),
                child: Text(
                  widget.days[index],
                  style: AppTextStyles.dayLabel,
                  softWrap: false, // keep label on one line
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}