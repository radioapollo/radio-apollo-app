/* Upcoming Badge Widget

   A small pill badge shown on event cards when the event is close.

   Three variants (most→least urgent):
   - "Vandaag"     — green, with pulsing animation, shown when the event
                     is today (daysUntil == 0)
   - "Bijna"       — red, with pulsing animation, shown when the event
                     is within 1 week (urgent, but not today)
   - "Binnenkort"  — blue, static, shown when the event is within 2 weeks

   The animation lives here so the consumer only has to pass the Event.
*/

import 'package:flutter/material.dart';
import '../../models/event.dart';
import '../../theme/app_theme.dart';

class UpcomingBadge extends StatelessWidget {
  final Event event;

  const UpcomingBadge({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final isToday = event.daysUntil == 0;
    final urgent = event.isWithinOneWeek;

    final String label;
    final Color color;
    final bool pulse;

    if (isToday) {
      label = 'Vandaag';

      color = AppColors.nowPlayingDot;
      pulse = true;
    } else if (urgent) {
      label = 'Bijna';
      color = AppColors.live;
      pulse = true;
    } else {
      label = 'Binnenkort';
      color = AppColors.primaryLight;
      pulse = false;
    }

    final badge = Container(
      margin: const EdgeInsets.only(left: AppDimensions.spaceSmall),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: pulse ? 0.5 : 0.3),
            blurRadius: pulse ? 8 : 4,
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textOnDark,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    return pulse ? _PulsingBadge(child: badge) : badge;
  }
}

// ── Pulsing animation wrapper ───────────────────────────────────────────────

class _PulsingBadge extends StatefulWidget {
  final Widget child;

  const _PulsingBadge({required this.child});

  @override
  State<_PulsingBadge> createState() => _PulsingBadgeState();
}

class _PulsingBadgeState extends State<_PulsingBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(
      begin: 1.0,
      end: 1.06,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _animation, child: widget.child);
  }
}
