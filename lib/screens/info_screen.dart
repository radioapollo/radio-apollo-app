/* Info Screen

   This screen provides general information about the radio station.

   It includes:
   - a fixed header (logo + title)
   - a scrollable content area with about text and sponsors
*/

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/sponsor.dart';
import '../services/info_service.dart';
import '../theme/app_theme.dart';
import '../constants/constants.dart';

class InfoScreen extends StatelessWidget {
  InfoScreen({super.key});

  final _infoService = InfoService();

  @override
  Widget build(BuildContext context) {
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
                    const Text('Over Radio Apollo',
                        style: AppTextStyles.screenTitle),
                    const SizedBox(height: AppDimensions.spaceLarge),
                  ],
                ),
              ),

              // Scrollable content
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimensions.paddingXLarge,
                    0,
                    AppDimensions.paddingXLarge,
                    AppDimensions.paddingXLarge,
                  ),
                  children: [
                    StreamBuilder<String>(
                      stream: _infoService.aboutTextStream,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(
                                color: AppColors.navyMedium),
                          );
                        }
                        if (snapshot.hasError ||
                            !snapshot.hasData ||
                            snapshot.data!.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return _buildInfoCard(snapshot.data!);
                      },
                    ),
                    const SizedBox(height: AppDimensions.space30),
                    const Text('Sponsors',
                        style: AppTextStyles.screenTitleSmall),
                    const SizedBox(height: AppDimensions.spaceLarge - 1),
                    StreamBuilder<List<Sponsor>>(
                      stream: _infoService.sponsorsStream,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator(
                                  color: AppColors.navyMedium));
                        }
                        if (snapshot.hasError) {
                          return const Text(
                              'Fout bij het laden van sponsors.',
                              style: AppTextStyles.noDataText);
                        }
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return const Text('Geen sponsors gevonden.',
                              style: AppTextStyles.noDataText);
                        }
                        return Column(
                          children: snapshot.data!
                              .map(_buildSponsorCard)
                              .toList(),
                        );
                      },
                    ),

                    // Developer credit
                    const SizedBox(height: AppDimensions.space30),
                    const Center(
                      child: Text(
                        'App ontwikkeld door Raf Vermeylen',
                        style: TextStyle(
                          color: AppColors.creditText,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(String text) => Container(
        padding: const EdgeInsets.all(AppDimensions.paddingLarge),
        decoration: AppDecorations.darkCard(),
        child: Text(text, style: AppTextStyles.darkCardBody),
      );

  Widget _buildSponsorCard(Sponsor sponsor) => Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.spaceXLarge),
      padding: const EdgeInsets.all(AppDimensions.paddingMedium),
      decoration: AppDecorations.lightCard(),
      child: Row(
        children: [
          if (sponsor.imageUrl != null && sponsor.imageUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: sponsor.imageUrl!,
                width: 60,
                height: 60,
                fit: BoxFit.contain,
                errorWidget: (_, __, ___) => const SizedBox(width: 60, height: 60),
              ),
            )
          else
            const SizedBox(width: 60, height: 60),
          const SizedBox(width: AppDimensions.spaceLarge),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sponsor.title, style: AppTextStyles.cardTitle),
                const SizedBox(height: AppDimensions.spaceXSmall),
                Text(sponsor.description, style: AppTextStyles.cardSubtitle),
              ],
            ),
          ),
        ],
      ),
    );
}