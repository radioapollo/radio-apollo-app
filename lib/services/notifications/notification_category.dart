/* Notification Category

   Single source of truth for the categories of push notification the
   app supports. Each category has:

   - topic         : the FCM topic name. Cloud Functions publish to
                     these topics; the client subscribes/unsubscribes
                     based on the user's toggle state.
   - channelId     : the Android notification channel ID. Each
                     category gets its own channel so users can
                     manage them separately in OS settings.
   - displayName   : the human-readable label shown in the in-app
                     Settings screen and in the OS channel list.
   - description   : a one-line explanation of what triggers a
                     notification in this category.
   - defaultEnabled: whether the category is on by default for new
                     installs. We default to ON for high-signal
                     categories (studio replies, events) and OFF
                     for noisier ones (general chat activity).
   - highImportance: when true the channel uses Android's HIGH
                     importance level, which means heads-up banners
                     and a noticeable sound. Use for things the
                     listener probably wants to react to right away
                     (studio replies, chat). Use false for things
                     that can be a quiet shade entry (events).

   Adding a new category? Add it here, add the matching trigger to
   the Cloud Functions backend, and the Settings screen will pick it
   up automatically.
*/

enum NotificationCategory {
  studioMessages(
    topic: 'studio_messages',
    channelId: 'nl.radioapollo.channel.studio_messages',
    displayName: 'Berichten van de studio',
    description: 'Wanneer de studio een bericht stuurt in de chat.',
    defaultEnabled: true,
    highImportance: true,
  ),
  chatActivity(
    topic: 'chat_activity',
    channelId: 'nl.radioapollo.channel.chat_activity',
    displayName: 'Chatactiviteit',
    description: 'Wanneer er nieuwe berichten zijn in de chat.',
    defaultEnabled: false,
    highImportance: true,
  ),
  events(
    topic: 'events',
    channelId: 'nl.radioapollo.channel.events',
    displayName: 'Evenementen',
    description: 'Een herinnering een week, een dag, en op de dag zelf.',
    defaultEnabled: true,
    highImportance: false,
  );

  // Note: a `showStarting` category is planned for when listeners can
  // mark programs as favorites. It's intentionally not listed here yet
  // because there's no Cloud Function publishing to it and no way to
  // pick a favorite, so showing the toggle would be misleading.

  const NotificationCategory({
    required this.topic,
    required this.channelId,
    required this.displayName,
    required this.description,
    required this.defaultEnabled,
    required this.highImportance,
  });

  final String topic;
  final String channelId;
  final String displayName;
  final String description;
  final bool defaultEnabled;
  final bool highImportance;
}