/* Info Screen

   This screen provides general information about the radio station.

   It includes:
   - a fixed header (logo + title)
   - a scrollable content area with about text, contact info, and sponsors
   - a developer credit and the app version number at the bottom

   The screen itself only wires together Firestore streams and the
   dedicated widgets in widgets/info/.
*/

import 'package:flutter/material.dart';
import '../models/sponsor.dart';
import '../services/info_service.dart';
import '../widgets/info/about_card.dart';
import '../widgets/info/contact_section.dart';
import '../widgets/info/sponsor_card.dart';
import '../widgets/info/app_version_footer.dart';
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
              _buildHeader(),
              Expanded(child: _buildContent()),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
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
          const Text('Over Radio Apollo', style: AppTextStyles.screenTitle),
          const SizedBox(height: AppDimensions.spaceLarge),
        ],
      ),
    );
  }

  // ── Scrollable content ────────────────────────────────────────────────────

  Widget _buildContent() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.paddingXLarge,
        0,
        AppDimensions.paddingXLarge,
        AppDimensions.paddingXLarge,
      ),
      children: [
        _buildAboutSection(),

        // ── Contact info ──────────────────────────────────────────────────
        const SizedBox(height: AppDimensions.space30),
        const Text('Contacteer ons', style: AppTextStyles.screenTitleSmall),
        const SizedBox(height: AppDimensions.spaceLarge - 1),
        const ContactSection(),

        // ── Sponsors ──────────────────────────────────────────────────────
        const SizedBox(height: AppDimensions.space30),
        const Text('Sponsors', style: AppTextStyles.screenTitleSmall),
        const SizedBox(height: AppDimensions.spaceLarge - 1),
        _buildSponsorsSection(),

        // ── Footer ────────────────────────────────────────────────────────
        const SizedBox(height: AppDimensions.space30),
        const AppVersionFooter(),
      ],
    );
  }

  // ── About section ─────────────────────────────────────────────────────────

  Widget _buildAboutSection() {
    return StreamBuilder<String>(
      stream: _infoService.aboutTextStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.navyMedium),
          );
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }
        return AboutCard(text: snapshot.data!);
      },
    );
  }

  // ── Sponsors section ──────────────────────────────────────────────────────

  Widget _buildSponsorsSection() {
    return StreamBuilder<List<Sponsor>>(
      stream: _infoService.sponsorsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.navyMedium),
          );
        }
        if (snapshot.hasError) {
          return const Text(
            'Fout bij het laden van sponsors.',
            style: AppTextStyles.noDataText,
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Text(
            'Geen sponsors gevonden.',
            style: AppTextStyles.noDataText,
          );
        }
        return Column(
          children: snapshot.data!.map((s) => SponsorCard(sponsor: s)).toList(),
        );
      },
    );
  }
}
