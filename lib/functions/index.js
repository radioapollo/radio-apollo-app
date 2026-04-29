/* Cloud Functions — Entry point

   Routes:
   - adminLogin: bcrypt-hashed admin password, rate-limited per IP
   - adminSendMessage: posts as "Studio" with a session token
   - userSendMessage: posts as a claimed username, soft App Check
   - claimUsername: atomic name claim, strict App Check
   - cleanupOldData: scheduled hourly, deletes expired data

   App Check policy:
   - claimUsername is STRICT — name squatting is the high-value attack.
   - userSendMessage is SOFT — failed App Check still goes through but
     under a stricter rate limit (USER_MSG_LIMIT_STRICT). This keeps
     Xiaomi/HyperOS users (whose Play Integrity often fails) able to
     chat, while throttling spam scripts hard.
*/

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const bcrypt = require('bcrypt');

admin.initializeApp();
const db = admin.firestore();

const {
  USER_MSG_WINDOW_MS,
  setCorsHeaders,
  getClientIp,
  verifyAppCheck,
  checkAndIncrementLoginAttempt,
  clearRateLimit,
  createSessionToken,
  validateSessionToken,
  checkUserMsgRateLimit,
  checkUserMsgRateLimitStrict,
} = require('./helpers');

const {
  onAdminChatMessage,
  onUserChatMessage,
  sendDailyEventReminders,
} = require('./notifications');

const CLEANUP_BATCH_LIMIT = 500;
const REGION = 'europe-west1';

const { checkProfanity } = require('./profanity');

// ═══════════════════════════════════════════════════════════════════════════
// Request helpers
// ═══════════════════════════════════════════════════════════════════════════

function preflight(req, res) {
  setCorsHeaders(req, res);
  if (req.method === 'OPTIONS') { res.status(204).send(''); return true; }
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return true;
  }
  return false;
}

// ═══════════════════════════════════════════════════════════════════════════
// adminLogin
// ═══════════════════════════════════════════════════════════════════════════

exports.adminLogin = functions.region(REGION).https.onRequest(async (req, res) => {
  if (preflight(req, res)) return;

  try {
    const { password } = req.body;
    if (!password) {
      res.status(400).json({ error: 'Password is required' });
      return;
    }

    const ip = getClientIp(req);
    const { locked, ref } = await checkAndIncrementLoginAttempt(ip);

    if (locked) {
      res.status(429).json({
        error: 'Te veel pogingen. Probeer het over 5 minuten opnieuw.',
      });
      return;
    }

    const configDoc = await db.collection('config').doc('admin').get();
    if (!configDoc.exists) {
      res.status(500).json({ error: 'Admin not configured' });
      return;
    }

    const ok = await bcrypt.compare(password, configDoc.data().passwordHash);
    if (!ok) {
      res.status(401).json({ error: 'Wachtwoord is niet juist.' });
      return;
    }

    await clearRateLimit(ref);
    const token = await createSessionToken();
    res.status(200).json({ token });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: 'Internal error' });
  }
});

// ═══════════════════════════════════════════════════════════════════════════
// adminSendMessage
// ═══════════════════════════════════════════════════════════════════════════

exports.adminSendMessage = functions.region(REGION).https.onRequest(async (req, res) => {
  if (preflight(req, res)) return;

  try {
    const { token, text } = req.body;
    if (!token || !text) {
      res.status(400).json({ error: 'Token and text are required' });
      return;
    }

    if (!await validateSessionToken(token)) {
      res.status(401).json({ error: 'Invalid or expired token' });
      return;
    }

    if (text.length > 160) {
      res.status(400).json({ error: 'Message too long (max 160 characters)' });
      return;
    }

    await db.collection('chat_messages').add({
      username: 'Studio',
      text,
      role: 'admin',
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    res.status(200).json({ success: true });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: 'Internal error' });
  }
});

// ═══════════════════════════════════════════════════════════════════════════
// userSendMessage (soft App Check)
// ═══════════════════════════════════════════════════════════════════════════

exports.userSendMessage = functions.region(REGION).https.onRequest(async (req, res) => {
  if (preflight(req, res)) return;

  try {
    const ip = getClientIp(req);
    const appCheckOk = await verifyAppCheck(req);
    if (!appCheckOk) {
      console.warn(
        `[userSendMessage] App Check soft-fail from IP ${ip}. ` +
        'Allowing through with strict rate limit.',
      );
    }

    const { username, text } = req.body;
    if (!username || !text) {
      res.status(400).json({ error: 'Username and text are required' });
      return;
    }

    const trimmedUsername = username.trim();
    const trimmed = text.trim();

    if (trimmedUsername.length < 2 || trimmedUsername.length > 20) {
      res.status(400).json({
        error: 'Gebruikersnaam moet tussen 2 en 20 tekens zijn.',
      });
      return;
    }
    if (trimmed.length === 0 || trimmed.length > 160) {
      res.status(400).json({ error: 'Bericht moet tussen 1 en 160 tekens zijn.' });
      return;
    }

    // Username must be claimed (claimUsername strictly enforces App Check,
    // so unclaimed names cannot be used to impersonate anyone).
    const claimDoc = await db
      .collection('usernames')
      .doc(trimmedUsername.toLowerCase())
      .get();
    if (!claimDoc.exists) {
      res.status(400).json({ error: 'Onbekende gebruikersnaam.' });
      return;
    }

    const bucket = `${ip}__${trimmedUsername.toLowerCase()}`;
    const canSend = appCheckOk
      ? await checkUserMsgRateLimit(bucket)
      : await checkUserMsgRateLimitStrict(bucket);

    if (!canSend) {
      res.status(429).json({ error: 'Je stuurt berichten te snel. Wacht even.' });
      return;
    }

    const filterResult = await checkProfanity(trimmed);
    if (filterResult.isSevere) {
      res.status(400).json({
        error: 'Dit bericht kan niet worden verzonden. Blijf vriendelijk.',
      });
      return;
    }

    await db.collection('chat_messages').add({
      username: trimmedUsername,
      text: filterResult.cleanedText,
      role: 'user',
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      appCheckVerified: appCheckOk,
    });

    res.status(200).json({ success: true });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: 'Internal error' });
  }
});

// ═══════════════════════════════════════════════════════════════════════════
// claimUsername (strict App Check)
// ═══════════════════════════════════════════════════════════════════════════

exports.claimUsername = functions.region(REGION).https.onRequest(async (req, res) => {
  if (preflight(req, res)) return;

  try {
    if (!await verifyAppCheck(req)) {
      res.status(401).json({ error: 'App Check verification failed.' });
      return;
    }

    const { name } = req.body;
    if (typeof name !== 'string') {
      res.status(400).json({ error: 'Name is required.' });
      return;
    }

    const trimmed = name.trim();
    if (trimmed.length < 3 || trimmed.length > 20) {
      res.status(400).json({ error: 'Naam moet tussen 3 en 20 tekens zijn.' });
      return;
    }

    const ref = db.collection('usernames').doc(trimmed.toLowerCase());

    try {
      await db.runTransaction(async (tx) => {
        const snap = await tx.get(ref);
        if (snap.exists) {
          const err = new Error('taken');
          err.code = 'taken';
          throw err;
        }
        tx.set(ref, {
          displayName: trimmed,
          claimedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      if (e && e.code === 'taken') {
        res.status(409).json({ error: 'Deze naam is al in gebruik. Kies een andere.' });
        return;
      }
      throw e;
    }

    res.status(200).json({ success: true, displayName: trimmed });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: 'Internal error' });
  }
});

// ═══════════════════════════════════════════════════════════════════════════
// cleanupOldData (scheduled hourly)
// ═══════════════════════════════════════════════════════════════════════════

exports.cleanupOldData = functions
  .region(REGION)
  .pubsub.schedule('every 1 hours')
  .timeZone('Europe/Brussels')
  .onRun(async (_context) => {
    const now = new Date();
    const messageCutoff = new Date(now.getTime() - 48 * 60 * 60 * 1000);
    const rateCutoff = new Date(now.getTime() - USER_MSG_WINDOW_MS * 2);

    await _deleteWhere(
      'chat_messages',
      ['timestamp', '<', messageCutoff],
      'old chat messages',
    );
    await _deleteWhere(
      '_admin_sessions',
      ['expiresAt', '<', now],
      'expired admin sessions',
    );
    await _deleteWhere(
      '_user_msg_limits',
      ['windowStart', '<', rateCutoff],
      'expired user rate limit records',
    );
    await _deletePastEvents();

    return null;
  });

async function _deleteWhere(collection, filter, label) {
  const snap = await db
    .collection(collection)
    .where(...filter)
    .limit(CLEANUP_BATCH_LIMIT)
    .get();

  if (snap.empty) {
    console.log(`No ${label}.`);
    return;
  }

  const batch = db.batch();
  snap.docs.forEach((doc) => batch.delete(doc.ref));
  await batch.commit();
  console.log(`Deleted ${snap.size} ${label}.`);
}

async function _deletePastEvents() {
  const todayStart = new Date();
  todayStart.setHours(0, 0, 0, 0);

  const snap = await db
    .collection('evenementen')
    .limit(CLEANUP_BATCH_LIMIT)
    .get();

  const toDelete = [];
  snap.docs.forEach((doc) => {
    const dateStr = doc.data().date;
    if (typeof dateStr !== 'string') return;

    const parsed = parseDutchDate(dateStr.trim().toLowerCase());
    if (!parsed) return;

    const eventDay = new Date(parsed.year, parsed.month - 1, parsed.day);
    eventDay.setHours(0, 0, 0, 0);

    if (eventDay < todayStart) toDelete.push(doc.ref);
  });

  if (toDelete.length === 0) {
    console.log('No past events to delete.');
    return;
  }

  const batch = db.batch();
  toDelete.forEach((ref) => batch.delete(ref));
  await batch.commit();
  console.log(`Deleted ${toDelete.length} past events.`);
}

const DUTCH_MONTHS = {
  januari: 1, februari: 2, maart: 3, april: 4, mei: 5, juni: 6,
  juli: 7, augustus: 8, september: 9, oktober: 10, november: 11, december: 12,
};

// ═══════════════════════════════════════════════════════════════════════════
// onChatMessageCreated — fans out push notifications for new chat messages
// ═══════════════════════════════════════════════════════════════════════════
//
// Fires for every new doc in /chat_messages. Routes admin messages to
// the studio_messages topic (high importance, banner) and user messages
// to the chat_activity topic (off by default on the client).
//
// We use an onCreate Firestore trigger rather than embedding the FCM
// call in adminSendMessage so that:
//   1. Any path that writes to the collection gets the notification —
//      adminSendMessage today, future admin panel, manual writes, etc.
//   2. The HTTP response to the admin doesn't wait on FCM.
//   3. If FCM is unavailable, the chat write still succeeds.

exports.onChatMessageCreated = functions
  .region(REGION)
  .firestore.document('chat_messages/{messageId}')
  .onCreate(async (snap, _context) => {
    const data = snap.data();
    if (!data) return null;

    if (data.role === 'admin') {
      await onAdminChatMessage(data);
    } else {
      await onUserChatMessage(data);
    }
    return null;
  });

// ═══════════════════════════════════════════════════════════════════════════
// dailyEventReminders — sends 7/1/0 day-out reminders for events
// ═══════════════════════════════════════════════════════════════════════════
//
// Runs once a day at 08:00 Europe/Brussels. Late enough to not wake
// people, early enough that someone going to a daytime event sees the
// reminder. The notifications module handles per-event idempotency
// using a `_lastReminderSentDate` field so a scheduler retry can't
// duplicate-send.

exports.dailyEventReminders = functions
  .region(REGION)
  .pubsub.schedule('0 8 * * *')
  .timeZone('Europe/Brussels')
  .onRun(async (_context) => {
    await sendDailyEventReminders(db, parseDutchDate);
    return null;
  });

function parseDutchDate(input) {
  const parts = input.split(/\s+/);
  if (parts.length !== 3) return null;

  const dayRaw = parts[0].split(/[/\-]/)[0];
  const day = parseInt(dayRaw, 10);
  const month = DUTCH_MONTHS[parts[1]];
  const year = parseInt(parts[2], 10);

  if (!day || !month || !year) return null;
  return { day, month, year };
}