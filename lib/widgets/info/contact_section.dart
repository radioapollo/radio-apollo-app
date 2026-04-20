/* Contact Section Widget

   Displays the station's contact details on the info screen:
   email, phone number, physical address, and Facebook page.

   Each row is tappable and opens the appropriate external app
   (mail client, dialer, maps, browser) via UrlLauncherUtils.
*/

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../utils/url_launcher_utils.dart';

class ContactSection extends StatelessWidget {
  const ContactSection({super.key});

  // ── Contact details ───────────────────────────────────────────────────────

  static const String _email = 'info@radioapollo.be';
  static const String _phone = '014/26.16.16';
  static const String _phoneDial = '003214261616';
  static const String _address = 'Lindestraat 7a, 2222 Wiekevorst';
  static const String _addressMap = 'https://g.co/kgs/3MCbeHw';
  static const String _facebookUrl =
      'https://www.facebook.com/people/Radio-Apollo/100039974545481/';
  static const String _privacyUrl =
      'https://radioapollo.github.io/radio-apollo-app/';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingLarge),
      decoration: AppDecorations.darkCard(),
      child: Column(
        children: [
          _ContactRow(
            icon: Icons.email_outlined,
            label: _email,
            onTap: () => UrlLauncherUtils.sendEmail(_email),
          ),
          const SizedBox(height: AppDimensions.spaceLarge),
          _ContactRow(
            icon: Icons.phone_outlined,
            label: _phone,
            onTap: () => UrlLauncherUtils.dialPhone(_phoneDial),
          ),
          const SizedBox(height: AppDimensions.spaceLarge),
          _ContactRow(
            icon: Icons.location_on_outlined,
            label: _address,
            onTap: () => UrlLauncherUtils.openUrl(_addressMap),
          ),
          const SizedBox(height: AppDimensions.spaceLarge),
          _ContactRow(
            icon: Icons.facebook,
            label: 'Radio Apollo op Facebook',
            onTap: () => UrlLauncherUtils.openUrl(_facebookUrl),
          ),
          const SizedBox(height: AppDimensions.spaceLarge),
          _ContactRow(
            icon: Icons.privacy_tip_outlined,
            label: 'Privacybeleid',
            onTap: () => UrlLauncherUtils.openUrl(_privacyUrl),
          ),
        ],
      ),
    );
  }
}

// ── Single contact row ──────────────────────────────────────────────────────

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ContactRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            icon,
            size: AppDimensions.iconLarge,
            color: AppColors.iconOnDarkMuted,
          ),
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
  }
}
