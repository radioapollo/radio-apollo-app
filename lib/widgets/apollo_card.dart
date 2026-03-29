/* Apollo Card Widget

   A reusable card component used throughout the application.

   It displays:
   - an icon
   - a title
   - a short description

   These cards are used on the home screen to navigate
   to different sections of the app.
*/

import 'package:flutter/material.dart';

enum CardLayout { horizontal, vertical }

class ApolloCard extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool big;
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
    this.big = false,
    this.darkText = false,
    this.onTap,
    this.layout = CardLayout.horizontal,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = darkText ? Colors.white : Colors.black87;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(22),
          border: border,
        ),
        child: layout == CardLayout.vertical
            ? _buildVerticalLayout(textColor)
            : _buildHorizontalLayout(textColor),
      ),
    );
  }

  Widget _buildVerticalLayout(Color textColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        Icon(icon, size: 36, color: textColor),
        const SizedBox(height: 12),
        Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: textColor,
            fontSize: 14,
            height: 1.3,
          ),
        ),
      ],
    );
  }

  Widget _buildHorizontalLayout(Color textColor) {
    return Row(
      children: [
        Icon(icon, size: 42, color: textColor),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            "$title\n$subtitle",
            style: TextStyle(
              color: textColor,
              fontSize: 15,
              height: 1.3,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}