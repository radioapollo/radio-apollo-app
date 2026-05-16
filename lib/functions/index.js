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

const REPLY_PREVIEW_MAX = 80;
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
  validateUserMessage,
  checkAndIncrementLoginAttempt,
  clearRateLimit,
  createSessionToken,
  validateSessionToken,
  checkUserMsgRateLimit,
  checkUserMsgRateLimitStrict,
  issueClaimToken,
  verifyClaimToken,
  isUsernameBanned,
} = require('./helpers');

const {
  onAdminChatMessage,
  onUserChatMessage,
  sendDailyEventReminders,
} = require('./notifications');

// Profanity filter is loaded from ./profanity.js, which reads the live
// word list from config/profanity in Firestore (with a hardcoded fallback)
// and caches the result for 60 seconds.
const { checkProfanity } = require('./profanity');

const CLEANUP_BATCH_LIMIT = 500;
const REGION = 'europe-west1';

// ═══════════════════════════════════════════════════════════════════════════
// Reply helpers
// ═══════════════════════════════════════════════════════════════════════════

/**
 * Builds a sanitized replyTo object from a request body.
 * Returns null if the body has no replyTo or it's malformed.
 */
function buildReplyToPayload(raw) {
  if (!raw || typeof raw !== 'object') return null;

  const messageId = raw.messageId;
  const username  = raw.username;
  const textPreview = raw.textPreview;

  if (typeof messageId !== 'string' || messageId.length === 0) return null;
  if (typeof username !== 'string'  || username.length === 0)  return null;
  if (typeof textPreview !== 'string') return null;

  let preview = textPreview.trim();
  if (preview.length > REPLY_PREVIEW_MAX) {
    preview = preview.slice(0, REPLY_PREVIEW_MAX - 1) + '…';
  }

  return {
    messageId: messageId.slice(0, 80),
    username: username.slice(0, 40),
    textPreview: preview,
  };
}

/**
 * Increments replyCount on the parent message. Used after a reply has
 * been written so the list view can render "💬 N" on the parent bubble.
 *
 * Best-effort: failure to increment doesn't roll back the reply. Worst
 * case is the count is off by one until the next reply lands.
 */
async function incrementReplyCount(parentId) {
  try {
    await db.collection('chat_messages').doc(String(parentId)).update({
      replyCount: admin.firestore.FieldValue.increment(1),
    });
  } catch (e) {
    console.warn('[chat] incrementReplyCount failed for', parentId, e?.message);
  }
}

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
    const { token, text, replyTo } = req.body;
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

    const sanitizedReplyTo = buildReplyToPayload(replyTo);

    const newMessage = {
      username: 'Studio',
      text,
      role: 'admin',
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      likes: 0,
      replyCount: 0,
    };
    if (sanitizedReplyTo) {
      newMessage.replyTo = sanitizedReplyTo;
    }

    await db.collection('chat_messages').add(newMessage);

    if (sanitizedReplyTo) {
      await incrementReplyCount(sanitizedReplyTo.messageId);
    }

    res.status(200).json({ success: true });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: 'Internal error' });
  }
});

// ═══════════════════════════════════════════════════════════════════════════
// adminBanUsername
// ═══════════════════════════════════════════════════════════════════════════
//
// Bans a username globally. The user can no longer send any chat message
// from any device, and the name cannot be re-claimed by someone else.
// Only callable with a valid admin session token.

exports.adminBanUsername = functions.region(REGION).https.onRequest(async (req, res) => {
  if (preflight(req, res)) return;

  try {
    const { token, username, reason } = req.body;
    if (!token || !username) {
      res.status(400).json({ error: 'Token and username are required' });
      return;
    }

    if (!await validateSessionToken(token)) {
      res.status(401).json({ error: 'Invalid or expired token' });
      return;
    }

    const trimmed = String(username).trim();
    if (trimmed.length === 0 || trimmed.length > 40) {
      res.status(400).json({ error: 'Invalid username' });
      return;
    }

    const lower = trimmed.toLowerCase();

    await db.collection('banned_usernames').doc(lower).set({
      displayName: trimmed,
      bannedAt: admin.firestore.FieldValue.serverTimestamp(),
      bannedBy: 'studio',
      reason: typeof reason === 'string' ? reason.slice(0, 200) : null,
    });

    res.status(200).json({ success: true });
  } catch (e) {
    console.error('adminBanUsername:', e);
    res.status(500).json({ error: 'Internal error' });
  }
});

// ═══════════════════════════════════════════════════════════════════════════
// adminUnbanUsername
// ═══════════════════════════════════════════════════════════════════════════

exports.adminUnbanUsername = functions.region(REGION).https.onRequest(async (req, res) => {
  if (preflight(req, res)) return;

  try {
    const { token, username } = req.body;
    if (!token || !username) {
      res.status(400).json({ error: 'Token and username are required' });
      return;
    }

    if (!await validateSessionToken(token)) {
      res.status(401).json({ error: 'Invalid or expired token' });
      return;
    }

    const lower = String(username).trim().toLowerCase();
    if (!lower) {
      res.status(400).json({ error: 'Invalid username' });
      return;
    }

    await db.collection('banned_usernames').doc(lower).delete();

    res.status(200).json({ success: true });
  } catch (e) {
    console.error('adminUnbanUsername:', e);
    res.status(500).json({ error: 'Internal error' });
  }
});

// ═══════════════════════════════════════════════════════════════════════════
// adminDeleteMessage
// ═══════════════════════════════════════════════════════════════════════════
//
// Deletes a single message from chat_messages. Used from the admin
// long-press menu and from the report review flow.

exports.adminDeleteMessage = functions.region(REGION).https.onRequest(async (req, res) => {
  if (preflight(req, res)) return;

  try {
    const { token, messageId } = req.body;
    if (!token || !messageId) {
      res.status(400).json({ error: 'Token and messageId are required' });
      return;
    }

    if (!await validateSessionToken(token)) {
      res.status(401).json({ error: 'Invalid or expired token' });
      return;
    }

    await db.collection('chat_messages').doc(String(messageId)).delete();

    res.status(200).json({ success: true });
  } catch (e) {
    console.error('adminDeleteMessage:', e);
    res.status(500).json({ error: 'Internal error' });
  }
});

// ═══════════════════════════════════════════════════════════════════════════
// adminUpdateReport
// ═══════════════════════════════════════════════════════════════════════════
//
// Marks a chat report as resolved or dismissed and records the action
// taken. Used from the admin reports inbox.

exports.adminUpdateReport = functions.region(REGION).https.onRequest(async (req, res) => {
  if (preflight(req, res)) return;

  try {
    const { token, reportId, status, action } = req.body;
    if (!token || !reportId || !status) {
      res.status(400).json({ error: 'token, reportId and status are required' });
      return;
    }

    if (!await validateSessionToken(token)) {
      res.status(401).json({ error: 'Invalid or expired token' });
      return;
    }

    const allowed = ['resolved', 'dismissed'];
    if (!allowed.includes(status)) {
      res.status(400).json({ error: 'Invalid status' });
      return;
    }

    await db.collection('chat_reports').doc(String(reportId)).update({
      status,
      action: typeof action === 'string' ? action.slice(0, 60) : null,
      resolvedAt: admin.firestore.FieldValue.serverTimestamp(),
      resolvedBy: 'studio',
    });

    res.status(200).json({ success: true });
  } catch (e) {
    console.error('adminUpdateReport:', e);
    res.status(500).json({ error: 'Internal error' });
  }
});

// ═══════════════════════════════════════════════════════════════════════════
// userSendMessage (soft App Check)
// ═══════════════════════════════════════════════════════════════════════════

exports.userSendMessage = functions
  .region(REGION)
  .runWith({ secrets: ['CLAIM_TOKEN_SECRET'] })
  .https.onRequest(async (req, res) => {
    if (preflight(req, res)) return;

    try {
      const ip = getClientIp(req);
      const appCheckOk = await verifyAppCheck(req);

      const { username, text, claimToken, replyTo } = req.body;
 
      const validation = validateUserMessage(username, text);
      if (!validation.ok) {
        res.status(400).json({ error: validation.error });
        return;
      }
      const trimmedUsername = validation.trimmedUsername;
      const trimmed = validation.trimmedText;

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

      // ─── Claim token verification ───────────────────────────────────────
      //
      // Without this, anyone who knows a username can post as them. With it,
      // the caller must present a JWT signed for the lowercased name.
      //
      // The token is App-Check-INDEPENDENT — Xiaomi/HyperOS users whose
      // Play Integrity is unreliable can still send because they got their
      // token at claim time, and that's all we check here.

      const decoded = verifyClaimToken(claimToken);
      if (!decoded || decoded.name !== trimmedUsername.toLowerCase()) {
        res.status(401).json({
          error: 'Authenticatie ontbreekt of ongeldig. Stel je gebruikersnaam opnieuw in.',
        });
        return;
      }

      // Username must be claimed (defense in depth — if the token is valid
      // but the username doc was deleted, reject).
      const claimDoc = await db
        .collection('usernames')
        .doc(trimmedUsername.toLowerCase())
        .get();
      if (!claimDoc.exists) {
        res.status(400).json({ error: 'Onbekende gebruikersnaam.' });
        return;
      }

      // If the username has been banned by an admin, block all sends from it.
      if (await isUsernameBanned(trimmedUsername)) {
        res.status(403).json({
          error: 'Je gebruikersnaam is geblokkeerd door de studio. Neem contact op via radioapollo.be als je denkt dat dit onterecht is.',
        });
        return;
      }

      // Use the canonical displayName from the claim doc, not the request body.
      // This means even if a client sends mixed case, what gets written is
      // the original casing the user claimed.
      const displayName = claimDoc.data().displayName || trimmedUsername;

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

      const sanitizedReplyTo = buildReplyToPayload(replyTo);

      const newMessage = {
        username: displayName,                 // server-derived, not from body
        text: filterResult.cleanedText,
        role: 'user',
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        appCheckVerified: appCheckOk,
        likes: 0,
        replyCount: 0,
      };
      if (sanitizedReplyTo) {
        newMessage.replyTo = sanitizedReplyTo;
      }

      await db.collection('chat_messages').add(newMessage);

      if (sanitizedReplyTo) {
        await incrementReplyCount(sanitizedReplyTo.messageId);
      }

      res.status(200).json({ success: true });
    } catch (e) {
      console.error(e);
      res.status(500).json({ error: 'Internal error' });
    }
  });


// ═══════════════════════════════════════════════════════════════════════════
// claimUsername (strict App Check)
// ═══════════════════════════════════════════════════════════════════════════

exports.claimUsername = functions
  .region(REGION)
  .runWith({ secrets: ['CLAIM_TOKEN_SECRET'] })
  .https.onRequest(async (req, res) => {
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

      // Don't let anyone re-claim a banned name.
      if (await isUsernameBanned(trimmed)) {
        res.status(403).json({ error: 'Deze naam is niet beschikbaar.' });
        return;
      }

      const ref = db.collection('usernames').doc(trimmed.toLowerCase());

      // Try to claim atomically. If the doc already exists with the SAME
      // displayName (case-insensitive), we treat it as a re-claim by the
      // same user and reissue a token instead of erroring.
      //
      // This is safe because the only way to call this endpoint is with a
      // valid App Check token, which means a real device. The first device
      // to claim a name "wins" — but if the same device opens the app again
      // it can re-fetch its token without going through a "name is taken"
      // error path that would block legitimate users from getting a token.
      //
      // If a DIFFERENT case is submitted (e.g. "Frank" was claimed, now
      // someone tries "FRANK"), we still 409 because the displayName differs
      // and someone else owns the canonical name.

      let isReissue = false;

      try {
        await db.runTransaction(async (tx) => {
          const snap = await tx.get(ref);
          if (snap.exists) {
            const existing = snap.data();
            // Same displayName? Treat as re-claim, reissue token.
            if (existing.displayName === trimmed) {
              isReissue = true;
              return;
            }
            // Different displayName but same lowercased ID — taken by someone else.
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

      // Issue a claim token. This is what the client stores and replays
      // on every userSendMessage call.
      let claimToken;
      try {
        claimToken = issueClaimToken(trimmed);
      } catch (e) {
        // Secret not configured. We've already written the username doc,
        // but can't issue a token. Surface a 500 — admin needs to set the
        // secret. Without it, the user can't send messages.
        console.error('issueClaimToken failed:', e);
        res.status(500).json({ error: 'Server-configuratiefout. Neem contact op.' });
        return;
      }

      res.status(200).json({
        success: true,
        claimToken,
        reissued: isReissue,
      });
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