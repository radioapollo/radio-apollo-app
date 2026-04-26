/* Cloud Functions — Entry point
   Exports: adminLogin, adminSendMessage, userSendMessage, claimUsername,
            cleanupOldData
   Helpers live in ./helpers.js for maintainability.
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
} = require('./helpers');

const CLEANUP_BATCH_LIMIT = 500;

// ═══════════════════════════════════════════════════════════════════════════
// Profanity Filter — Server-Side Enforcement
// ═══════════════════════════════════════════════════════════════════════════

const SEVERE_WORDS_DUTCH = [
  'hoer', 'kankerlijer', 'kankerhond', 'mongool', 'mof', 'nikker',
  'tyfuslijer', 'kutwijf', 'teringlijder', 'klootzak', 'verkrachten', 'neuken'
];

const SEVERE_WORDS_ENGLISH = [
  'nigger', 'nigga', 'faggot', 'retard', 'tranny', 'chink', 'spic',
  'rape', 'molest', 'kill yourself', 'kys'
];

const MILD_WORDS_DUTCH = [
  'kut', 'shit', 'fuck', 'godverdomme', 'verdomme', 'klote', 'lul',
  'eikel', 'stom', 'debiel', 'idioot', 'sufkop'
];

const MILD_WORDS_ENGLISH = [
  'fuck', 'shit', 'damn', 'hell', 'ass', 'asshole', 'bitch', 'bastard',
  'crap', 'piss', 'dick', 'cock', 'pussy', 'whore', 'slut'
];

const ALL_SEVERE = [...SEVERE_WORDS_DUTCH, ...SEVERE_WORDS_ENGLISH];
const ALL_MILD = [...MILD_WORDS_DUTCH, ...MILD_WORDS_ENGLISH];

function normalize(text) {
  let s = text.toLowerCase();
  s = s.replace(/\s+/g, '');
  s = s.replace(/(.)\1{2,}/g, '$1$1');
  const leetMap = {
    '0': 'o', '1': 'i', '3': 'e', '4': 'a', '5': 's',
    '7': 't', '8': 'b', '@': 'a', '$': 's', '!': 'i'
  };
  for (const [leet, normal] of Object.entries(leetMap)) {
    s = s.replace(new RegExp(leet.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'g'), normal);
  }
  return s;
}

function containsWord(normalized, badWord) {
  const escaped = badWord.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const regex = new RegExp(`(?:^|\\b)${escaped}(?:$|\\b)`);
  return regex.test(normalized);
}

function censorWord(text, badWord) {
  const escaped = badWord.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const regex = new RegExp(`(?:^|\\b)${escaped}(?:$|\\b)`, 'gi');
  return text.replace(regex, (match) => {
    if (match.length <= 2) return '*'.repeat(match.length);
    return match[0] + '*'.repeat(match.length - 2) + match[match.length - 1];
  });
}

function checkProfanity(message) {
  const normalized = normalize(message);

  for (const word of ALL_SEVERE) {
    if (containsWord(normalized, word)) {
      return { isSevere: true, cleanedText: message };
    }
  }

  let cleaned = message;
  for (const word of ALL_MILD) {
    if (containsWord(normalized, word)) {
      cleaned = censorWord(cleaned, word);
    }
  }

  return { isSevere: false, cleanedText: cleaned };
}

// ═══════════════════════════════════════════════════════════════════════════
// Admin Login (atomic rate limit, trusted proxy IP only)
// ═══════════════════════════════════════════════════════════════════════════

exports.adminLogin = functions.region('europe-west1').https.onRequest(async (req, res) => {
  setCorsHeaders(req, res);

  if (req.method === 'OPTIONS') { res.status(204).send(''); return; }
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  try {
    const { password } = req.body;
    if (!password) {
      res.status(400).json({ error: 'Password is required' });
      return;
    }

    // Check + increment in a single Firestore transaction so racing
    // requests can't all read the same stale counter.
    const ip = getClientIp(req);
    const { locked, attempts, ref } = await checkAndIncrementLoginAttempt(ip);

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
    const hash = configDoc.data().passwordHash;

    const ok = await bcrypt.compare(password, hash);
    if (!ok) {
      // Counter was already incremented atomically before bcrypt.
      res.status(401).json({ error: 'Wachtwoord is niet juist.' });
      return;
    }

    // Successful login — reset the counter so this user isn't penalised
    // for past failed attempts.
    await clearRateLimit(ref);
    const token = await createSessionToken();
    res.status(200).json({ token });

  } catch (e) {
    console.error(e);
    res.status(500).json({ error: 'Internal error' });
  }
});

// ═══════════════════════════════════════════════════════════════════════════
// Admin Send Message
// ═══════════════════════════════════════════════════════════════════════════

exports.adminSendMessage = functions.region('europe-west1').https.onRequest(async (req, res) => {
  setCorsHeaders(req, res);

  if (req.method === 'OPTIONS') { res.status(204).send(''); return; }
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  try {
    const { token, text } = req.body;

    if (!token || !text) {
      res.status(400).json({ error: 'Token and text are required' });
      return;
    }

    const valid = await validateSessionToken(token);
    if (!valid) {
      res.status(401).json({ error: 'Invalid or expired token' });
      return;
    }

    if (text.length > 160) {
      res.status(400).json({ error: 'Message too long (max 160 characters)' });
      return;
    }

    await db.collection('chat_messages').add({
      username: 'Studio',
      text: text,
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
// User Send Message (App Check required, IP+username rate-limited)
// ═══════════════════════════════════════════════════════════════════════════

exports.userSendMessage = functions.region('europe-west1').https.onRequest(async (req, res) => {
  setCorsHeaders(req, res);

  if (req.method === 'OPTIONS') { res.status(204).send(''); return; }
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  try {
    const appCheckOk = await verifyAppCheck(req);
    if (!appCheckOk) {
      res.status(401).json({ error: 'App Check verification failed.' });
      return;
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
      res.status(400).json({
        error: 'Bericht moet tussen 1 en 160 tekens zijn.',
      });
      return;
    }

    const claimDoc = await db
      .collection('usernames')
      .doc(trimmedUsername.toLowerCase())
      .get();
    if (!claimDoc.exists) {
      res.status(400).json({ error: 'Onbekende gebruikersnaam.' });
      return;
    }

    const ip = getClientIp(req);
    const bucket = `${ip}__${trimmedUsername.toLowerCase()}`;
    const canSend = await checkUserMsgRateLimit(bucket);
    if (!canSend) {
      res.status(429).json({
        error: 'Je stuurt berichten te snel. Wacht even.',
      });
      return;
    }

    const filterResult = checkProfanity(trimmed);
    if (filterResult.isSevere) {
      res.status(400).json({
        error: 'Dit bericht kan niet worden verzonden. Blijf vriendelijk.',
      });
      return;
    }
    const textToStore = filterResult.cleanedText;

    await db.collection('chat_messages').add({
      username: trimmedUsername,
      text: textToStore,
      role: 'user',
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    res.status(200).json({ success: true });

  } catch (e) {
    console.error(e);
    res.status(500).json({ error: 'Internal error' });
  }
});

// ═══════════════════════════════════════════════════════════════════════════
// Claim Username (App Check required)
// ═══════════════════════════════════════════════════════════════════════════

exports.claimUsername = functions.region('europe-west1').https.onRequest(async (req, res) => {
  setCorsHeaders(req, res);

  if (req.method === 'OPTIONS') { res.status(204).send(''); return; }
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  try {
    const appCheckOk = await verifyAppCheck(req);
    if (!appCheckOk) {
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

    const docId = trimmed.toLowerCase();
    const ref = db.collection('usernames').doc(docId);

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
        res.status(409).json({
          error: 'Deze naam is al in gebruik. Kies een andere.',
        });
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
// Scheduled Cleanup
// ═══════════════════════════════════════════════════════════════════════════

exports.cleanupOldData = functions
  .region('europe-west1')
  .pubsub.schedule('every 1 hours')
  .timeZone('Europe/Brussels')
  .onRun(async (_context) => {
    const messageCutoff = new Date(Date.now() - 24 * 60 * 60 * 1000);
    const now = new Date();

    // ── Chat messages (24h TTL) ───────────────────────────────────────
    const msgSnap = await db
      .collection('chat_messages')
      .where('timestamp', '<', messageCutoff)
      .limit(CLEANUP_BATCH_LIMIT)
      .get();

    if (!msgSnap.empty) {
      const batch = db.batch();
      msgSnap.docs.forEach((doc) => batch.delete(doc.ref));
      await batch.commit();
      console.log(`Deleted ${msgSnap.size} old chat messages.`);
    } else {
      console.log('No old chat messages.');
    }

    // ── Expired admin sessions ────────────────────────────────────────
    const sessionSnap = await db
      .collection('_admin_sessions')
      .where('expiresAt', '<', now)
      .limit(CLEANUP_BATCH_LIMIT)
      .get();

    if (!sessionSnap.empty) {
      const batch = db.batch();
      sessionSnap.docs.forEach((doc) => batch.delete(doc.ref));
      await batch.commit();
      console.log(`Deleted ${sessionSnap.size} expired admin sessions.`);
    }

    // ── Expired user message rate limit records ───────────────────────
    const rateCutoff = new Date(Date.now() - USER_MSG_WINDOW_MS * 2);
    const rateSnap = await db
      .collection('_user_msg_limits')
      .where('windowStart', '<', rateCutoff)
      .limit(CLEANUP_BATCH_LIMIT)
      .get();

    if (!rateSnap.empty) {
      const batch = db.batch();
      rateSnap.docs.forEach((doc) => batch.delete(doc.ref));
      await batch.commit();
      console.log(`Deleted ${rateSnap.size} expired user rate limit records.`);
    }

    // ── Past events ────────────────────────────────────────────────────
    const todayStart = new Date();
    todayStart.setHours(0, 0, 0, 0);

    const eventsSnap = await db
      .collection('evenementen')
      .limit(CLEANUP_BATCH_LIMIT)
      .get();

    const toDelete = [];

    eventsSnap.docs.forEach((doc) => {
      const dateStr = doc.data().date;
      if (!dateStr || typeof dateStr !== 'string') return;

      const parsed = parseDutchDate(dateStr.trim().toLowerCase());
      if (!parsed) return;

      const eventDay = new Date(parsed.year, parsed.month - 1, parsed.day);
      eventDay.setHours(0, 0, 0, 0);

      if (eventDay < todayStart) {
        toDelete.push(doc.ref);
      }
    });

    if (toDelete.length > 0) {
      const batch = db.batch();
      toDelete.forEach((ref) => batch.delete(ref));
      await batch.commit();
      console.log(`Deleted ${toDelete.length} past events.`);
    } else {
      console.log('No past events to delete.');
    }

    return null;
  });

// ── Helper: Parse Dutch date ────────────────────────────────────────────────

function parseDutchDate(input) {
  const dutchMonths = {
    januari: 1, februari: 2, maart: 3, april: 4, mei: 5, juni: 6,
    juli: 7, augustus: 8, september: 9, oktober: 10, november: 11, december: 12,
  };

  const parts = input.split(/\s+/);
  if (parts.length !== 3) return null;

  const dayRaw = parts[0].split(/[/\-]/)[0];
  const day = parseInt(dayRaw, 10);
  const month = dutchMonths[parts[1]];
  const year = parseInt(parts[2], 10);

  if (!day || !month || !year) return null;

  return { day, month, year };
}