/* Info Screen

   This screen provides general information about the radio station.

   It includes:
   - a description of the station
   - a list of sponsors loaded from Firestore
*/

import 'package:flutter/material.dart';
import '../models/sponsor.dart';
import '../services/info_services.dart';
import '../widgets/page_with_header.dart';
import '../theme/app_theme.dart';

class InfoScreen extends StatelessWidget {
  InfoScreen({super.key});

  final _infoService = InfoService();

  static const _aboutText =
      'Radio Apollo staat voor feel-good muziek, lokale verbondenheid en een warme sfeer. '
      'We brengen een mix van classics, hedendaagse hits en lokale informatie.\n\n'
      'Onze missie is om luisteraars plezier, nieuws en gezelligheid te brengen – altijd en overal.';

  @override
  Widget build(BuildContext context) {
    return PageWithHeader(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Over Radio Apollo', style: AppTextStyles.screenTitle),
          const SizedBox(height: AppDimensions.spaceLarge - 1),
          _buildInfoCard(),
          const SizedBox(height: AppDimensions.space30),
          const Text('Sponsors', style: AppTextStyles.screenTitleSmall),
          const SizedBox(height: AppDimensions.spaceLarge - 1),
          StreamBuilder<List<Sponsor>>(
            stream: _infoService.sponsorsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.navyMedium));
              }
              if (snapshot.hasError) {
                return const Text('Fout bij het laden van sponsors.',
                    style: AppTextStyles.noDataText);
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Text('Geen sponsors gevonden.',
                    style: AppTextStyles.noDataText);
              }
              return Column(
                children: snapshot.data!.map(_buildSponsorCard).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() => Container(
        padding: const EdgeInsets.all(AppDimensions.paddingLarge),
        decoration: AppDecorations.darkCard(),
        child: const Text(_aboutText, style: AppTextStyles.darkCardBody),
      );

  Widget _buildSponsorCard(Sponsor sponsor) => Container(
        margin: const EdgeInsets.only(bottom: AppDimensions.spaceXLarge),
        padding: const EdgeInsets.all(AppDimensions.paddingMedium),
        decoration: AppDecorations.lightCard(),
        child: Row(
          children: [
            const SizedBox(width: AppDimensions.spaceLarge),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(sponsor.title, style: AppTextStyles.cardTitle),
                  const SizedBox(height: AppDimensions.spaceXSmall),
                  Text(sponsor.description,
                      style: AppTextStyles.cardSubtitle),
                ],
              ),
            ),
          ],
        ),
      );
}