/* Info Screen

   This screen provides general information about the radio station.

   It includes:
   - a fixed header (logo + title)
   - a scrollable content area with about text, contact info, and sponsors
   - a developer credit and the app version number at the bottom

   ─── No more flicker on tab swipe ──────────────────────────────────────────
   The two Firestore streams (about text + sponsors) used to be looked up
   through `_infoService.aboutTextStream` / `sponsorsStream` inside each
   `_build…Section()` call. Those getters previously built a brand-new
   `.snapshots()` stream every time, so StreamBuilder reset to
   `ConnectionState.waiting` on every rebuild — including every frame of
   a PageView swipe. That caused the "flitst en hapert" flash between
   Programma's and Info.

   We now:
     1. Cache the streams as broadcast streams inside InfoService.
     2. Capture each stream once in State so the StreamBuilder sees the
        same identity across rebuilds and keeps its last snapshot.
     3. Pass `initialData` from the service's latest-value cache so the
        very first build after opening the app is also flicker-free as
        soon as any data has arrived.
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
import 'settings_screen.dart';

class InfoScreen extends StatefulWidget {
  const InfoScreen({super.key});

  @override
  State<InfoScreen> createState() => _InfoScreenState();
}

class _InfoScreenState extends State<InfoScreen>
    with AutomaticKeepAliveClientMixin {
  final _infoService = InfoService.instance;

  late final Stream<String> _aboutTextStream = _infoService.aboutTextStream;
  late final Stream<List<Sponsor>> _sponsorsStream =
      _infoService.sponsorsStream;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SizedBox.expand(
      child: Container(
        decoration: BoxDecoration(
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
          Row(
            children: [
              Expanded(
                child: Text(
                  'Over Radio Apollo',
                  style: AppTextStyles.screenTitle,
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.settings_outlined,
                  color: AppColors.textPrimary,
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),
            ],
          ),
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
        Text('Contacteer ons', style: AppTextStyles.screenTitleSmall),
        const SizedBox(height: AppDimensions.spaceLarge - 1),
        const ContactSection(),

        // ── Sponsors ──────────────────────────────────────────────────────
        const SizedBox(height: AppDimensions.space30),
        Text('Sponsors', style: AppTextStyles.screenTitleSmall),
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
      stream: _aboutTextStream,
      initialData: _infoService.latestAboutText,
      builder: (context, snapshot) {

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
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
      stream: _sponsorsStream,
      initialData: _infoService.latestSponsors,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.navyMedium),
          );
        }
        if (snapshot.hasError) {
          return Text(
            'Fout bij het laden van sponsors.',
            style: AppTextStyles.noDataText,
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Text(
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
