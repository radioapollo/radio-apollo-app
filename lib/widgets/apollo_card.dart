/* Apollo Card Widget

   A reusable card component used throughout the application.

   It displays:
   - an icon
   - a title
   - a short description

   Supports both vertical and horizontal layouts, and is
   used on the home screen to navigate to different sections.
*/

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum CardLayout { horizontal, vertical }

class ApolloCard extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool darkText;
  final VoidCallback? onTap;
  final CardLayout layout;
  final Border? border;

  const ApolloCard({
    super.key,
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.darkText = false,
    this.onTap,
    this.layout = CardLayout.horizontal,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = darkText ? AppColors.textOnDark : AppColors.textBody;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.paddingLarge),
        decoration: AppDecorations.colorCard(color: color, border: border),
        child: layout == CardLayout.vertical
            ? _buildVertical(textColor)
            : _buildHorizontal(textColor),
      ),
    );
  }

  Widget _buildVertical(Color textColor) => Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: AppTextStyles.apolloCardTitle.copyWith(color: textColor)),
          const SizedBox(height: AppDimensions.paddingSmall),
          Icon(icon, size: AppDimensions.iconXXLarge, color: textColor),
          const SizedBox(height: AppDimensions.paddingSmall),
          Text(subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.cardSubtitle.copyWith(color: textColor)),
        ],
      );

  Widget _buildHorizontal(Color textColor) => Row(
        children: [
          Icon(icon, size: AppDimensions.iconPlayer, color: textColor),
          const SizedBox(width: AppDimensions.paddingSmall),
          Expanded(
            child: Text(
              '$title\n$subtitle',
              style: AppTextStyles.apolloCardSubtitle.copyWith(color: textColor),
            ),
          ),
        ],
      );
}