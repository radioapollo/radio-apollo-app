/* URL Launcher Utils

   Thin helpers around url_launcher that all do the same dance:
   parse → canLaunchUrl → launchUrl. Pulled out of info_screen so
   the screen file doesn't redefine them inline.

   All helpers silently no-op if the URL/scheme is not supported
   on the current device. Callers do not need to handle errors.
*/

import 'package:url_launcher/url_launcher.dart';

class UrlLauncherUtils {
  UrlLauncherUtils._();

  static Future<void> openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  static Future<void> dialPhone(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  static Future<void> sendEmail(String email) async {
    final uri = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
