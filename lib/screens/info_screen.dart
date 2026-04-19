/* Info Screen

   This screen provides general information about the radio station.

   It includes:
   - a fixed header (logo + title)
   - a scrollable content area with about text, contact info, and sponsors
   - the app version number shown at the bottom
*/

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/sponsor.dart';
import '../services/info_service.dart';
import '../theme/app_theme.dart';
import '../constants/constants.dart';
import 'package:url_launcher/url_launcher.dart';

class InfoScreen extends StatelessWidget {
  InfoScreen({super.key});

  final _infoService = InfoService();

  // ── URL helpers ───────────────────────────────────────────────────────────

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchPhone(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchEmail(String email) async {
    final uri = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

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
                    // ── About text ──────────────────────────────────────
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

                    // ── Contact info ────────────────────────────────────
                    const SizedBox(height: AppDimensions.space30),
                    const Text('Contacteer ons',
                        style: AppTextStyles.screenTitleSmall),
                    const SizedBox(height: AppDimensions.spaceLarge - 1),
                    _buildContactSection(),

                    // ── Sponsors ────────────────────────────────────────
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

                    // ── Version number ──────────────────────────────────
                    const SizedBox(height: AppDimensions.spaceSmall),
                    Center(
                      child: Text(
                        'Versie ${AppConstants.appVersion}',
                        style: const TextStyle(
                          color: AppColors.creditText,
                          fontSize: 11,
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

  // ── About card ──────────────────────────────────────────────────────────

  Widget _buildInfoCard(String text) => Container(
        padding: const EdgeInsets.all(AppDimensions.paddingLarge),
        decoration: AppDecorations.darkCard(),
        child: Text(text, style: AppTextStyles.darkCardBody),
      );

  // ── Contact section ───────────────────────────────────────────────────────

  Widget _buildContactSection() => Container(
        padding: const EdgeInsets.all(AppDimensions.paddingLarge),
        decoration: AppDecorations.darkCard(),
        child: Column(
          children: [
            _buildContactRow(
              icon: Icons.email_outlined,
              label: 'info@radioapollo.be',
              onTap: () => _launchEmail('info@radioapollo.be'),
            ),
            const SizedBox(height: AppDimensions.spaceLarge),
            _buildContactRow(
              icon: Icons.phone_outlined,
              label: '014/26.16.16',
              onTap: () => _launchPhone('003214261616'),
            ),
            const SizedBox(height: AppDimensions.spaceLarge),
            _buildContactRow(
              icon: Icons.location_on_outlined,
              label: 'Lindestraat 7a, 2222 Wiekevorst',
              onTap: () => _launchUrl('https://g.co/kgs/3MCbeHw'),
            ),
            const SizedBox(height: AppDimensions.spaceLarge),
            _buildContactRow(
              icon: Icons.facebook,
              label: 'Radio Apollo op Facebook',
              onTap: () => _launchUrl(
                  'https://www.facebook.com/people/Radio-Apollo/100039974545481/'),
            ),
          ],
        ),
      );

  Widget _buildContactRow({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon,
                size: AppDimensions.iconLarge,
                color: AppColors.iconOnDarkMuted),
            const SizedBox(width: AppDimensions.spaceLarge),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.darkCardSubtitle.copyWith(
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.textOnDarkMedium,
                ),
              ),
            ),
            const Icon(
              Icons.open_in_new,
              size: 16,
              color: AppColors.iconOnDarkMuted,
            ),
          ],
        ),
      );

  // ── Sponsor card ──────────────────────────────────────────────────────────

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