/* Cloud Functions — Notifications

   Helpers and the per-trigger logic for publishing FCM messages to
   topics. Nothing here is a Cloud Function itself — it's just plain
   functions exported for the triggers in index.js to call. This keeps
   index.js focused on routing and lets us unit-test the logic later
   without bringing up the functions framework.

   Channel IDs
   ───────────
   Every FCM message MUST specify a channel ID matching one created on
   the client (see notification_category.dart). Without it FCM falls
   back to the default channel (importance=DEFAULT, no heads-up). The
   manifest also names a fallback channel; we don't rely on it.

   Topics
   ──────
   Topic names match NotificationCategory.topic on the client:
     - studio_messages → admin chat replies, heads-up
     - chat_activity   → all user messages (off by default), heads-up
     - events          → event reminders 7 / 1 / 0 days out, quiet

   Reminder dedup
   ──────────────
   The scheduled job stores `_lastReminderSentDate` on each event doc
   after sending. If the function reruns the same day (scheduler retry,
   a manual invocation, etc), we skip events that already got their
   reminder for today. Field gets overwritten on the next eligible
   day, so it grows at most one field per event.
*/

const admin = require('firebase-admin');

// Channel IDs — must match notification_category.dart on the client.
const CHANNEL_STUDIO_MESSAGES = 'be.radioapollo.channel.studio_messages';
const CHANNEL_CHAT_ACTIVITY   = 'be.radioapollo.channel.chat_activity';
const CHANNEL_EVENTS          = 'be.radioapollo.channel.events';

// Topic names — must match NotificationCategory.topic.
const TOPIC_STUDIO_MESSAGES = 'studio_messages';
const TOPIC_CHAT_ACTIVITY   = 'chat_activity';
const TOPIC_EVENTS          = 'events';

// Truncation limits. FCM allows much longer payloads but the visible
// notification body is clipped by Android anyway, so trim for free.
const MAX_TITLE_LEN = 60;
const MAX_BODY_LEN  = 200;

// ─── FCM send ──────────────────────────────────────────────────────────────

/**
 * Sends one FCM message to a topic with the channel ID baked in.
 *
 * The `data.category` field lets the foreground client route to the
 * matching local channel when rendering the notification itself (see
 * _displayForegroundMessage in notification_service.dart).
 */
async function sendToTopic({ topic, channelId, title, body, category }) {
  const message = {
    topic,
    notification: {
      title: truncate(title, MAX_TITLE_LEN),
      body: truncate(body, MAX_BODY_LEN),
    },
    android: {
      priority: 'high',
      notification: {
        channelId,
        // Match the channel-side `showWhen: false` for the foreground
        // path. Background notifications rendered by FCM use this.
        defaultSound: true,
      },
    },
    data: {
      // Stringified because FCM data values must be strings.
      category,
    },
  };

  try {
    const messageId = await admin.messaging().send(message);
    console.log(`[FCM] Sent to topic=${topic} channel=${channelId} id=${messageId}`);
  } catch (e) {
    // Best-effort: log and move on. We never want a failed FCM call to
    // break the Firestore write that triggered it.
    console.error(`[FCM] Failed to send to topic=${topic}:`, e);
  }
}

// ─── Studio chat trigger ───────────────────────────────────────────────────

/**
 * Called from the onCreate trigger on `chat_messages`. Publishes a
 * notification to the studio_messages topic for any new admin message.
 *
 * Returns a Promise<void>. Caller awaits to keep the function alive
 * until the FCM send finishes — Cloud Functions kill execution as
 * soon as the trigger handler returns.
 */
async function onAdminChatMessage(messageData) {
  const text = (messageData.text || '').trim();
  if (!text) return;

  await sendToTopic({
    topic: TOPIC_STUDIO_MESSAGES,
    channelId: CHANNEL_STUDIO_MESSAGES,
    title: 'Bericht van de studio',
    body: text,
    category: TOPIC_STUDIO_MESSAGES,
  });
}

/**
 * Called from the onCreate trigger on `chat_messages`. Publishes a
 * lower-volume notification to the chat_activity topic for any new
 * non-admin message. Subscribers are off by default in the client
 * (NotificationCategory.chatActivity.defaultEnabled = false).
 */
async function onUserChatMessage(messageData) {
  const username = (messageData.username || 'Iemand').trim() || 'Iemand';
  const text = (messageData.text || '').trim();
  if (!text) return;

  await sendToTopic({
    topic: TOPIC_CHAT_ACTIVITY,
    channelId: CHANNEL_CHAT_ACTIVITY,
    title: `Nieuw bericht van ${username}`,
    body: text,
    category: TOPIC_CHAT_ACTIVITY,
  });
}

// ─── Daily event reminders ─────────────────────────────────────────────────

/**
 * Iterates the `evenementen` collection and sends reminders for events
 * that fall 7 / 1 / 0 days from today. Uses parseDutchDate (passed in
 * to avoid a circular require with index.js) to handle both single-day
 * dates ("3 mei 2026") and multi-day ranges ("30/31 mei 2026"), where
 * the start day is what matters for reminders.
 *
 * Idempotent within a single day: each event is marked with
 * `_lastReminderSentDate = YYYY-MM-DD` after notification, and skipped
 * if that field already equals today. Means a retry won't duplicate.
 *
 * @param {object} db          - admin.firestore() instance
 * @param {function} parseDutchDate - existing helper from index.js
 */
async function sendDailyEventReminders(db, parseDutchDate) {
  const todayStart = new Date();
  todayStart.setHours(0, 0, 0, 0);
  const todayKey = formatDateKey(todayStart);

  const snap = await db.collection('evenementen').get();
  if (snap.empty) {
    console.log('[events] No events in collection, nothing to remind.');
    return;
  }

  let remindedCount = 0;
  let skippedDuplicate = 0;
  let skippedUnparseable = 0;

  for (const doc of snap.docs) {
    const data = doc.data();

    // Already reminded today? Skip — keeps retries idempotent.
    if (data._lastReminderSentDate === todayKey) {
      skippedDuplicate++;
      continue;
    }

    const dateStr = data.date;
    if (typeof dateStr !== 'string') {
      skippedUnparseable++;
      continue;
    }

    const parsed = parseDutchDate(dateStr.trim().toLowerCase());
    if (!parsed) {
      skippedUnparseable++;
      continue;
    }

    const eventDay = new Date(parsed.year, parsed.month - 1, parsed.day);
    eventDay.setHours(0, 0, 0, 0);

    const daysUntil = Math.round(
      (eventDay.getTime() - todayStart.getTime()) / (24 * 60 * 60 * 1000),
    );

    const reminderText = buildEventReminderText(data, daysUntil);
    if (!reminderText) continue; // not 7 / 1 / 0 days out

    await sendToTopic({
      topic: TOPIC_EVENTS,
      channelId: CHANNEL_EVENTS,
      title: reminderText.title,
      body: reminderText.body,
      category: TOPIC_EVENTS,
    });

    // Mark as sent so a retry today won't re-send. We do this AFTER
    // the FCM call rather than before, so a partial failure (FCM
    // unreachable) doesn't lock us out of retrying. Last-write-wins
    // is fine here — duplicate reminders are worse than missed ones.
    await doc.ref.update({ _lastReminderSentDate: todayKey });

    remindedCount++;
  }

  console.log(
    `[events] Reminded ${remindedCount} event(s); ` +
    `skipped ${skippedDuplicate} already-reminded, ` +
    `${skippedUnparseable} unparseable.`,
  );
}

// ─── Helpers ───────────────────────────────────────────────────────────────

/**
 * Returns the title/body for a 7-day, 1-day, or 0-day reminder.
 * Returns null for any other days_until value (no reminder).
 */
function buildEventReminderText(eventData, daysUntil) {
  const name = (eventData.title || eventData.name || 'Een evenement').trim();
  const location = (eventData.location || '').trim();

  // Friendly suffix mentioning the location only when present.
  const where = location ? ` in ${location}` : '';

  switch (daysUntil) {
    case 7:
      return {
        title: 'Volgende week: ' + name,
        body: `${name}${where} vindt plaats over een week.`,
      };
    case 1:
      return {
        title: 'Morgen: ' + name,
        body: `${name}${where} is morgen.`,
      };
    case 0:
      return {
        title: 'Vandaag: ' + name,
        body: `${name}${where} vindt vandaag plaats.`,
      };
    default:
      return null;
  }
}

function formatDateKey(date) {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

function truncate(s, max) {
  if (typeof s !== 'string') return '';
  if (s.length <= max) return s;
  return s.slice(0, max - 1) + '…';
}

module.exports = {
  onAdminChatMessage,
  onUserChatMessage,
  sendDailyEventReminders,
  // Exported for tests / direct triggers if ever needed.
  sendToTopic,
  buildEventReminderText,
  formatDateKey,
};