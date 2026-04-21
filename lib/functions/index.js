/* Cloud Functions — Entry point
   Exports: adminLogin, adminSendMessage, userSendMessage, cleanupOldData
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
  checkRateLimit,
  recordFailedAttempt,
  clearRateLimit,
  createSessionToken,
  validateSessionToken,
  checkUserMsgRateLimit,
} = require('./helpers');

// Maximum documents to process per cleanup run (prevents timeout)
const CLEANUP_BATCH_LIMIT = 500;

// ═══════════════════════════════════════════════════════════════════════════
// Profanity Filter — Server-Side Enforcement
// ═══════════════════════════════════════════════════════════════════════════
//
// Usage: called automatically by userSendMessage before writing to Firestore.

// ── Word lists ───────────────────────────────────────────────────────────────

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

// ── Filter logic ─────────────────────────────────────────────────────────────

/**
 * Normalize text for profanity detection.
 * Handles: leetspeak, spacing, repeated chars, mixed case.
 */
function normalize(text) {
  let s = text.toLowerCase();

  // Remove spaces (catches "f u c k")
  s = s.replace(/\s+/g, '');

  // Collapse repeated chars (fuuuuck → fuck)
  s = s.replace(/(.)\1{2,}/g, '$1$1');

  // Leetspeak substitutions
  const leetMap = {
    '0': 'o', '1': 'i', '3': 'e', '4': 'a', '5': 's',
    '7': 't', '8': 'b', '@': 'a', '$': 's', '!': 'i'
  };
  for (const [leet, normal] of Object.entries(leetMap)) {
    s = s.replace(new RegExp(leet.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'g'), normal);
  }

  return s;
}

/**
 * Check if normalized text contains a bad word (with word boundaries).
 */
function containsWord(normalized, badWord) {
  // Match word at start, end, middle, or in compounds
  const escaped = badWord.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const regex = new RegExp(`(?:^|\\b)${escaped}(?:$|\\b)`);
  return regex.test(normalized);
}

/**
 * Replace a bad word with asterisks in the original text.
 * Keeps first and last letter: "fuck" → "f**k"
 */
function censorWord(text, badWord) {
  // Match word at start, end, middle, or in compounds
  const escaped = badWord.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const regex = new RegExp(`(?:^|\\b)${escaped}(?:$|\\b)`, 'gi');
  return text.replace(regex, (match) => {
    if (match.length <= 2) return '*'.repeat(match.length);
    return match[0] + '*'.repeat(match.length - 2) + match[match.length - 1];
  });
}

/**
 * Check message for profanity and return result.
 * 
 * Returns object: { isSevere: bool, cleanedText: string }
 * - isSevere === true → block the message
 * - isSevere === false, cleanedText !== original → censored mild words
 */
function checkProfanity(message) {
  const normalized = normalize(message);

  // Check for severe words first (hard block)
  for (const word of ALL_SEVERE) {
    if (containsWord(normalized, word)) {
      return { isSevere: true, cleanedText: message };
    }
  }

  // Check for mild words (auto-censor)
  let cleaned = message;
  let foundMild = false;

  for (const word of ALL_MILD) {
    if (containsWord(normalized, word)) {
      foundMild = true;
      cleaned = censorWord(cleaned, word);
    }
  }

  return { isSevere: false, cleanedText: cleaned };
}

// ─── Admin Login (with rate limiting + token) ───────────────────────────────

exports.adminLogin = functions.region('europe-west1').https.onRequest(async (req, res) => {
  setCorsHeaders(req, res);

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

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

    // ── Rate limiting ───────────────────────────────────────────────────
    const ip = req.ip || req.headers['x-forwarded-for'] || 'unknown';
    const { locked, ref, attempts } = await checkRateLimit(ip);

    if (locked) {
      res.status(429).json({
        error: 'Te veel pogingen. Probeer het over 5 minuten opnieuw.',
      });
      return;
    }

    // ── Password check ──────────────────────────────────────────────────
    const doc = await db.collection('config').doc('admin').get();

    if (!doc.exists) {
      res.status(404).json({ error: 'Admin config not found' });
      return;
    }

    const match = await bcrypt.compare(password, doc.data().passwordHash);

    if (!match) {
      await recordFailedAttempt(ref, attempts);
      res.status(401).json({ error: 'Invalid password' });
      return;
    }

    // ── Success — create session token ──────────────────────────────────
    await clearRateLimit(ref);
    const token = await createSessionToken();
    res.status(200).json({ success: true, token });

  } catch (e) {
    console.error(e);
    res.status(500).json({ error: 'Internal error' });
  }
});

// ─── Admin Send Message (token-based) ───────────────────────────────────────

exports.adminSendMessage = functions.region('europe-west1').https.onRequest(async (req, res) => {
  setCorsHeaders(req, res);

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  try {
    const { token, text } = req.body;

    // ── Validate inputs ─────────────────────────────────────────────────
    if (!token || !text) {
      res.status(400).json({ error: 'Token and text are required' });
      return;
    }

    // ── Validate token ──────────────────────────────────────────────────
    const valid = await validateSessionToken(token);
    if (!valid) {
      res.status(401).json({ error: 'Invalid or expired token' });
      return;
    }

    // ── Validate message length ────────────────────────────────────────
    if (text.length > 160) {
      res.status(400).json({ error: 'Message too long (max 160 characters)' });
      return;
    }

    // ── Write admin message ─────────────────────────────────────────────
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

// ─── User Send Message ──────────────────────────────────────────────────────

exports.userSendMessage = functions.region('europe-west1').https.onRequest(async (req, res) => {
  setCorsHeaders(req, res);

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  try {
    const { username, text } = req.body;

    // ── Validate inputs ─────────────────────────────────────────────────
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

    // ── Rate limiting (10 messages per minute per username) ────────────
    const canSend = await checkUserMsgRateLimit(trimmedUsername);
    if (!canSend) {
      res.status(429).json({
        error: 'Je stuurt berichten te snel. Wacht even.',
      });
      return;
    }

    // ── Write message ───────────────────────────────────────────────────
    // ── Profanity check ─────────────────────────────────────────────────
    const filterResult = checkProfanity(trimmed);

    if (filterResult.isSevere) {
      res.status(400).json({
        error: 'Dit bericht kan niet worden verzonden. Blijf vriendelijk.',
      });
      return;
    }

    // Use censored text if mild profanity was detected
    const textToStore = filterResult.cleanedText;

    // ── Write message ───────────────────────────────────────────────────
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

// ─── Scheduled Cleanup ──────────────────────────────────────────────────────
//
// Runs every hour. Deletes:
//   - chat_messages older than 24 hours
//   - expired admin sessions
//   - expired user message rate limit records
//   - past events (events whose date has passed)
//
// Each query uses limit() to prevent timeouts on large datasets.
// If the limit is reached, the next hourly run picks up the rest.
//
// NOTE: Usernames are kept permanently so they cannot be re-claimed.

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
    // Delete events whose date has passed (midnight today or earlier).
    // Events with unparseable dates are kept to avoid accidental deletion.
    
    const todayStart = new Date();
    todayStart.setHours(0, 0, 0, 0);

    const eventsSnap = await db
      .collection('evenementen')
      .limit(CLEANUP_BATCH_LIMIT)
      .get();

    const toDelete = [];
    
    eventsSnap.docs.forEach((doc) => {
      const dateStr = doc.data().date;
      if (!dateStr || typeof dateStr !== 'string') {
        return; // Keep events without a date field
      }

      const parsed = parseDutchDate(dateStr.trim().toLowerCase());
      if (!parsed) {
        return; // Keep events with unparseable dates
      }

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
// Matches the logic in lib/utils/date_utils.dart

function parseDutchDate(input) {
  const dutchMonths = {
    januari: 1, februari: 2, maart: 3, april: 4, mei: 5, juni: 6,
    juli: 7, augustus: 8, september: 9, oktober: 10, november: 11, december: 12,
  };

  const parts = input.split(/\s+/);
  if (parts.length !== 3) return null;

  // Support "30/31 mei 2026" by taking the first number before /
  const dayRaw = parts[0].split(/[/\-]/)[0];
  const day = parseInt(dayRaw, 10);
  const month = dutchMonths[parts[1]];
  const year = parseInt(parts[2], 10);

  if (!day || !month || !year) return null;

  return { day, month, year };
}