/* Program Screen

   This screen shows the weekly radio program schedule.

   It includes:
   - a fixed header (logo + title + day selector)
   - a scrollable program list contained below the header
   - highlighting of the currently playing program
   - auto scroll to the current program
   - automatic refresh every minute to update the current program
*/

import 'dart:async';
import 'package:flutter/material.dart';
import '../services/program_service.dart';
import '../widgets/program_card.dart';
import '../widgets/day_selector.dart';
import '../theme/app_theme.dart';
import '../constants/constants.dart';

class ProgramScreen extends StatefulWidget {
  const ProgramScreen({super.key});

  @override
  State<ProgramScreen> createState() => _ProgramScreenState();
}

class _ProgramScreenState extends State<ProgramScreen> {
  final _programService = ProgramService();
  final _scrollController = ScrollController();
  late List<String> _days;
  int _selectedIndex = 3;
  bool _hasScrolledToCurrent = false;
  Timer? _timer;
  //int _lastCurrentIndex = -1;

  @override
  void initState() {
    super.initState();
    _days = _programService.getShiftedDays(_selectedIndex);
    // Only rebuild when the current program might have changed
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (_isToday()) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  String _formatTime(String time) {
    if (time == '24:00') return '00:00';
    return time;
  }

  String _formatTimeRange(String start, String end) {
    return '${_formatTime(start)} - ${_formatTime(end)}';
  }

  bool _isCurrent(String startTime, String endTime, bool isToday) {
    if (!isToday) return false;

    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;

    int parseTime(String time) {
      final parts = time.split(':');
      return int.parse(parts[0]) * 60 + int.parse(parts[1]);
    }

    final start = parseTime(startTime);
    final end = parseTime(endTime);

    if (end <= start) {
      return currentMinutes >= start || currentMinutes < end;
    }

    return currentMinutes >= start && currentMinutes < end;
  }

  bool _isToday() {
    final todayName = ProgramService.weekdays[DateTime.now().weekday - 1];
    return _days[_selectedIndex] == todayName;
  }

  void _scrollToCurrent(int currentIndex) {
    if (!_hasScrolledToCurrent) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients && currentIndex >= 0) {
          final offset =
              currentIndex * AppDimensions.programCardHeight;
          _scrollController.animateTo(
            offset.clamp(0, _scrollController.position.maxScrollExtent),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
          );
          _hasScrolledToCurrent = true;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedDay = _days[_selectedIndex];
    final isToday = _isToday();

    return SizedBox.expand(
      child: Container(
        decoration: const BoxDecoration(
          image: AppDecorations.backgroundWatermark,
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fixed header
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.paddingXLarge,
                  AppDimensions.paddingXLarge,
                  AppDimensions.paddingXLarge,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Image.asset(
                      AppAssets.logo,
                      height: AppDimensions.logoHeight,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: AppDimensions.spaceMedium),
                    const Text('Programma',
                        style: AppTextStyles.screenTitle),
                    const SizedBox(height: AppDimensions.paddingXLarge),
                    DaySelector(
                      days: _days,
                      selectedIndex: _selectedIndex,
                      onDaySelected: (i) => setState(() {
                        _selectedIndex = i;
                        _hasScrolledToCurrent = false;
                      }),
                    ),
                    const SizedBox(height: AppDimensions.spaceLarge),
                  ],
                ),
              ),

              // Scrollable program list in contained area
              Expanded(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(
                    AppDimensions.paddingXLarge,
                    0,
                    AppDimensions.paddingXLarge,
                    AppDimensions.paddingXLarge,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.transparent,
                  ),
                  child: StreamBuilder<List<Map<String, String>>>(
                    stream: _programService.getProgramsForDay(selectedDay),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.steelLight,
                          ),
                        );
                      }
                      if (snapshot.hasError) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(
                                AppDimensions.paddingXLarge),
                            child: Text(
                              'Fout bij het laden van programma\'s.',
                              style: AppTextStyles.noDataText,
                            ),
                          ),
                        );
                      }
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(
                                AppDimensions.paddingXLarge),
                            child: Text(
                              'Geen programma\'s gevonden.',
                              style: AppTextStyles.noDataText,
                            ),
                          ),
                        );
                      }

                      final programs = snapshot.data!;

                      int currentIndex = -1;
                      if (isToday) {
                        for (int i = 0; i < programs.length; i++) {
                          final timeParts =
                              programs[i]['time']!.split(' - ');
                          if (timeParts.length == 2) {
                            if (_isCurrent(
                                timeParts[0], timeParts[1], isToday)) {
                              currentIndex = i;
                              break;
                            }
                          }
                        }
                        if (currentIndex >= 0) {
                          _scrollToCurrent(currentIndex);
                        }
                      }

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(
                            AppDimensions.paddingMedium),
                        itemCount: programs.length,
                        itemBuilder: (context, index) {
                          final p = programs[index];
                          final timeParts = p['time']!.split(' - ');
                          final displayTime = timeParts.length == 2
                              ? _formatTimeRange(
                                  timeParts[0], timeParts[1])
                              : p['time']!;
                          return ProgramCard(
                            time: displayTime,
                            title: p['title']!,
                            subtitle: p['desc']!,
                            imageUrl: p['imageUrl'] ?? '',
                            isCurrent: index == currentIndex,
                            border: Border.all(
                              color: Colors.white24,
                              width: AppDimensions.borderThin,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}