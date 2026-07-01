/* Update Service

   Checks the Google Play Store for a newer version of the app and,
   if one is available, shows Play's native in-app update flow.

   Android-only: the in_app_update plugin wraps Google Play Core, which
   has no iOS equivalent. On any non-Android platform this is a no-op.
   Only works for builds installed from the Play Store (including the
   internal test track). Called from _initInBackground, well after
   runApp(), so it never delays the first frame.
*/

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

class UpdateService {
  UpdateService._();

  static Future<void> checkForUpdate() async {
    if (kIsWeb || !Platform.isAndroid) return;

    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        await InAppUpdate.startFlexibleUpdate();
        await InAppUpdate.completeFlexibleUpdate();
      }
    } catch (e) {
      debugPrint('[UpdateService] update check failed: $e');
    }
  }
}
