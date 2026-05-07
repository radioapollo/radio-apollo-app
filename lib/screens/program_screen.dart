/* Program Screen

   This screen shows the weekly radio program schedule.

   It includes:
   - a fixed header (logo + title + day selector)
   - a scrollable program list contained below the header
   - highlighting of the currently playing program
   - auto scroll to the current program
   - automatic refresh every minute to update the current program
   - resets to today when the user navigates back to this tab

   ─── No more flicker on tab swipe ──────────────────────────────────────────
   `ProgramService.getProgramsForDay` now returns a cached broadcast
   stream — the same stream instance for the same day across rebuilds.
   StreamBuilder therefore keeps its last snapshot, so swiping into
   Programma's (or diagonally into Info while the list is scrolling)
   no longer flashes the spinner.

   `initialData` is filled from the service's latest-value cache so
   that even the very first rebuild after switching days has data on
   screen straight away, as long as that day has been loaded once
   before during the session.

   Live updates still work:
     - Firestore changes push through the broadcast stream, updating
       the list.
     - A local Timer.periodic(1 minute) calls setState, which re-runs
       `isCurrentTimeInRange` so "NU BEZIG" moves to the next program
       at the right moment even if no DB change happened.
*/

import 'dart:async';
import 'package:flutter/material.dart';
import '../services/program/program_service.dart';
import '../utils/date_utils.dart';
import '../widgets/program/program_card.dart';
import '../widgets/program/day_selector.dart';
import '../theme/app_theme.dart';
import '../constants/constants.dart';

class ProgramScreen extends StatefulWidget {
  final bool isActive;

  const ProgramScreen({super.key, this.isActive = false});

  @override
  State<ProgramScreen> createState() => _ProgramScreenState();
}

class _ProgramScreenState extends State<ProgramScreen>
    with AutomaticKeepAliveClientMixin {
  final _programService = ProgramService();
  final _scrollController = ScrollController();
  late List<String> _days;
  int _selectedIndex = 3;
  bool _hasScrolledToCurrent = false;
  Timer? _timer;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _days = _programService.getShiftedDays(_selectedIndex);
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (_isToday()) {
        setState(() {});
      }
    });
  }

  @override
  void didUpdateWidget(covariant ProgramScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isActive && !oldWidget.isActive) {
      _resetToToday();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _resetToToday() {
    setState(() {
      _selectedIndex = 3;
      _days = _programService.getShiftedDays(_selectedIndex);
      _hasScrolledToCurrent = false;
    });
  }

  bool _isToday() {
    final todayName = ProgramService.weekdays[DateTime.now().weekday - 1];
    return _days[_selectedIndex] == todayName;
  }

  void _scrollToCurrent(int currentIndex) {
    if (!_hasScrolledToCurrent) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients &&
            _scrollController.position.hasContentDimensions &&
            currentIndex >= 0) {
          final offset = currentIndex * AppDimensions.programCardHeight;
          _scrollController.animateTo(
            offset.clamp(0, _scrollController.position.maxScrollExtent),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
          );
          _hasScrolledToCurrent = true;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final selectedDay = _days[_selectedIndex];
    final isToday = _isToday();

    return SizedBox.expand(
      child: Container(
        decoration: BoxDecoration(image: AppDecorations.backgroundWatermark),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                    Text("Programma's", style: AppTextStyles.screenTitle),
                    const SizedBox(height: AppDimensions.spaceLarge),
                    DaySelector(
                      days: _days,
                      selectedIndex: _selectedIndex,
                      onDaySelected: (index) => setState(() {
                        _selectedIndex = index;
                        _hasScrolledToCurrent = false;
                      }),
                    ),
                    const SizedBox(height: AppDimensions.spaceLarge),
                  ],
                ),
              ),

              Expanded(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(
                    AppDimensions.paddingXLarge,
                    0,
                    AppDimensions.paddingXLarge,
                    AppDimensions.paddingXLarge,
                  ),
                  child: StreamBuilder<List<Map<String, String>>>(
                    stream: _programService.getProgramsForDay(selectedDay),

                    initialData: _programService.latestForDay(selectedDay),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          !snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.steelLight,
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: EdgeInsets.all(
                              AppDimensions.paddingXLarge,
                            ),
                            child: Text(
                              'Fout bij het laden van programma\'s.',
                              style: AppTextStyles.noDataText,
                            ),
                          ),
                        );
                      }

                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: EdgeInsets.all(
                              AppDimensions.paddingXLarge,
                            ),
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
                          final timeParts = programs[i]['time']!.split(' - ');
                          if (timeParts.length == 2 &&
                              AppDateUtils.isCurrentTimeInRange(
                                timeParts[0],
                                timeParts[1],
                              )) {
                            currentIndex = i;
                            break;
                          }
                        }
                        if (currentIndex >= 0) {
                          _scrollToCurrent(currentIndex);
                        }
                      }

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(
                          AppDimensions.paddingMedium,
                        ),
                        itemCount: programs.length,
                        itemBuilder: (context, index) {
                          final p = programs[index];
                          final timeParts = p['time']!.split(' - ');
                          final displayTime = timeParts.length == 2
                              ? AppDateUtils.formatTimeRange(
                                  timeParts[0],
                                  timeParts[1],
                                )
                              : p['time']!;
                          return ProgramCard(
                            time: displayTime,
                            title: p['title']!,
                            subtitle: p['desc']!,
                            imageUrl: p['imageUrl'] ?? '',
                            isCurrent: index == currentIndex,
                            border: Border.all(
                              color: AppColors.overlayLight,
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
