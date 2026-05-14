/* URL Launcher Utils

   Thin helpers around url_launcher that wrap the launch call in a
   try/catch and ignore failures.

   ─── Why no canLaunchUrl precheck ──────────────────────────────────────────
   Previous versions did `canLaunchUrl` → `launchUrl`. The precheck is
   an additional platform-channel round-trip on every tap. On some
   Android devices (especially the first tap after a cold start) it
   measurably lagged behind the user's intent, and when it returned
   false we silently no-op'd with no feedback to the user — so a tap on
   a contact row would just look like nothing happened, and the user
   would tap again. The second tap could race with the first.

   The launches we care about are well-known schemes (tel:, mailto:,
   https:) declared in AndroidManifest.xml's <queries> block, so the
   system permits them. If `launchUrl` fails because the device has no
   app for the scheme, we catch the exception and log it. That's
   strictly better than the silent-no-op fallback the precheck gave us.
*/

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class UrlLauncherUtils {
  UrlLauncherUtils._();

  static Future<void> openUrl(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('[UrlLauncherUtils] openUrl failed for "$url": $e');
    }
  }

  static Future<void> dialPhone(String number) async {
    try {
      await launchUrl(Uri(scheme: 'tel', path: number));
    } catch (e) {
      debugPrint('[UrlLauncherUtils] dialPhone failed for "$number": $e');
    }
  }

  static Future<void> sendEmail(String email) async {
    try {
      await launchUrl(Uri(scheme: 'mailto', path: email));
    } catch (e) {
      debugPrint('[UrlLauncherUtils] sendEmail failed for "$email": $e');
    }
  }
}
