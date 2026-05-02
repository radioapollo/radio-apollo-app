/* App Constants

   Central definition of all constant string values
   used throughout the application such as URLs,
   Firestore collection names, and notification config.
*/

class AppConstants {
  AppConstants._();

  // ── Stream URLs ───────────────────────────────────────────────────────────

  static const String streamUrl =
      'http://radioapollo.beheerstream.nl:8006/stream';
  static const String statsUrl =
      'http://radioapollo.beheerstream.nl:8006/stats?json=1';

  // ── App version ───────────────────────────────────────────────────────────
  //
  // Shown at the bottom of the info screen. Keep in sync with the
  // `version:` field in pubspec.yaml.

  static const String appVersion = '1.0.0';

  // ── Firestore collections ─────────────────────────────────────────────────

  static const String firestoreSponsors = 'sponsors';

  // ── Notification ──────────────────────────────────────────────────────────

  static const String notificationChannelId = 'be.radioapollo.channel.audio';
  static const String notificationChannelName = 'Radio Apollo';

  // ── Cloud Functions ───────────────────────────────────────────────────────

  static const String projectId = 'radio-apollo-90693';
  static const String region = 'europe-west1';

  static String cloudFunctionUrl(String functionName) =>
      'https://$region-$projectId.cloudfunctions.net/$functionName';

  // ── External URLs ─────────────────────────────────────────────────────────
  static const String privacyPolicyUrl =
      'https://radioapollo.github.io/Apollo_Radio/';
  static const String termsOfUseUrl =
      'https://radioapollo.github.io/Apollo_Radio/terms.html';
}
