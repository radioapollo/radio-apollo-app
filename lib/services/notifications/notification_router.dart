/* Notification Router

   Central place for "the user tapped a notification — which tab
   should the app land on?". Three message-arrival paths feed into
   this:

     1. Cold start (app was terminated). FirebaseMessaging
        .getInitialMessage() returns the message that launched the
        app, called once during NotificationService.init().
     2. Background tap (app was in background, FCM rendered the
        banner). FirebaseMessaging.onMessageOpenedApp fires a stream
        event when the user taps.
     3. Foreground tap (app was visible, our local plugin rendered
        the banner). flutter_local_notifications fires
        onDidReceiveNotificationResponse from its initialize()
        callback.

   We funnel all three into setRequestedTabForCategory(). ApolloNav
   listens to `requestedTab` and switches to the requested index,
   then calls consume() so the same tap doesn't re-fire on the next
   rebuild.

   Why a ValueNotifier
   ───────────────────
   ApolloNav is the root stateful widget. It rebuilds rarely and we
   don't want to pull in a state-management package for one int.
   ValueNotifier is built into Flutter, plays nicely with
   ValueListenableBuilder, and survives hot reload. Good enough.

   Tab mapping (must match the order of children in ApolloNav's
   PageView):
     0 Home
     1 Programma's
     2 Info
     3 Evenementen   ← events
     4 Chat          ← studio_messages, chat_activity
*/

import 'package:flutter/foundation.dart';

class NotificationRouter {
  NotificationRouter._();
  static final NotificationRouter instance = NotificationRouter._();

  /// Tab index ApolloNav should switch to. Null when there is nothing
  /// pending. ApolloNav reads, switches, and calls [consume] to reset.
  final ValueNotifier<int?> requestedTab = ValueNotifier<int?>(null);

  /// Translates a notification's `category` data field into a tab
  /// index and stores it. Safe to call before ApolloNav has mounted —
  /// the value sticks until consumed.
  void setRequestedTabForCategory(String? categoryString) {
    final tab = _tabForCategory(categoryString);
    if (tab == null) return;
    requestedTab.value = tab;
  }

  /// Called by ApolloNav after acting on a requested tab. Resetting to
  /// null prevents the same tap from re-firing on the next rebuild.
  void consume() {
    requestedTab.value = null;
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  /// Maps a `data.category` value (the topic name we put in every
  /// outgoing FCM payload) to a tab index in ApolloNav.
  int? _tabForCategory(String? raw) {
    if (raw == null) return null;
    switch (raw) {
      case 'studio_messages':
      case 'chat_activity':
        return 4; // Chat tab
      case 'events':
        return 3; // Evenementen tab
      default:
        debugPrint('[NotificationRouter] Unknown category: $raw');
        return null;
    }
  }
}