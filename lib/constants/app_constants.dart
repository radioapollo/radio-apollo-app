/* App Constants
   Central definition of all constant string values
   used throughout the application such as URLs,
   Firestore collection names, and notification config.
*/

class AppConstants {
  AppConstants._();

  // Stream URLs
  static const String streamUrl =
      'http://radioapollo.beheerstream.nl:8004/stream';
  static const String statsUrl =
      'http://radioapollo.beheerstream.nl:8006/stats?json=1';

  // Firestore collections
  static const String firestoreSponsors = 'sponsors';

  // Notification
  static const String notificationChannelId =
      'nl.radioapollo.channel.audio';
  static const String notificationChannelName = 'Radio Apollo';

  static const String projectId = 'radio-apollo-90693';
  
  static const String region = 'europe-west1';
}