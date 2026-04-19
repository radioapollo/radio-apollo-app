/* Sponsor Card Widget

   Displays a single sponsor on the info screen.

   It shows:
   - the sponsor logo (or a blank placeholder if no image is set)
   - the sponsor title
   - a short promotional description
*/

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../models/sponsor.dart';
import '../../theme/app_theme.dart';

class SponsorCard extends StatelessWidget {
  final Sponsor sponsor;

  const SponsorCard({super.key, required this.sponsor});

  static const double _logoSize = 60.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin:  const EdgeInsets.only(bottom: AppDimensions.spaceXLarge),
      padding: const EdgeInsets.all(AppDimensions.paddingMedium),
      decoration: AppDecorations.lightCard(),
      child: Row(
        children: [
          _buildLogo(),
          const SizedBox(width: AppDimensions.spaceLarge),
          Expanded(child: _buildInfo()),
        ],
      ),
    );
  }

  // ── Logo ──────────────────────────────────────────────────────────────────

  Widget _buildLogo() {
    final hasImage =
        sponsor.imageUrl != null && sponsor.imageUrl!.isNotEmpty;

    if (!hasImage) {
      return const SizedBox(width: _logoSize, height: _logoSize);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: sponsor.imageUrl!,
        width:    _logoSize,
        height:   _logoSize,
        fit:      BoxFit.contain,
        errorWidget: (_, _, _) =>
            const SizedBox(width: _logoSize, height: _logoSize),
      ),
    );
  }

  // ── Info ──────────────────────────────────────────────────────────────────

  Widget _buildInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(sponsor.title, style: AppTextStyles.cardTitle),
        const SizedBox(height: AppDimensions.spaceXSmall),
        Text(sponsor.description, style: AppTextStyles.cardSubtitle),
      ],
    );
  }
}