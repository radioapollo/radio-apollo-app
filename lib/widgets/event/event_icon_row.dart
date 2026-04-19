/* Event Icon Row

   A small internal helper widget used by the event card and detail sheet
   to render an icon with a label beside it (e.g. date, location).

   When [accent] is non-null the icon and text are tinted and the label
   is bolded — used to highlight upcoming event dates.
*/

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class EventIconRow extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color?   accent;

  const EventIconRow({
    super.key,
    required this.icon,
    required this.label,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon,
            size:  AppDimensions.iconSmall,
            color: accent ?? AppColors.textMeta),
        const SizedBox(width: AppDimensions.spaceXSmall),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.cardMeta.copyWith(
              color: accent,
              fontWeight:
                  accent != null ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
}