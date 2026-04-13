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
    if (!token) {
      res.status(400).json({ error: 'Token is required' });
      return;
    }

    if (!text || typeof text !== 'string') {
      res.status(400).json({ error: 'Message text is required' });
      return;
    }

    const trimmed = text.trim();
    if (trimmed.length === 0 || trimmed.length > 160) {
      res.status(400).json({ error: 'Message must be 1–160 characters' });
      return;
    }

    // ── Verify session token ────────────────────────────────────────────
    const valid = await validateSessionToken(token);

    if (!valid) {
      res.status(401).json({ error: 'Invalid or expired session' });
      return;
    }

    // ── Write the admin message ─────────────────────────────────────────
    await db.collection('chat_messages').add({
      username: 'Radio Apollo',
      text: trimmed,
      role: 'admin',
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    res.status(200).json({ success: true });

  } catch (e) {
    console.error(e);
    res.status(500).json({ error: 'Internal error' });
  }
});

// ─── User Send Message (with rate limiting) ─────────────────────────────────

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
    const { text, username } = req.body;

    // ── Validate inputs ─────────────────────────────────────────────────
    if (!text || typeof text !== 'string') {
      res.status(400).json({ error: 'Message text is required' });
      return;
    }

    const trimmed = text.trim();
    if (trimmed.length === 0 || trimmed.length > 160) {
      res.status(400).json({ error: 'Message must be 1–160 characters' });
      return;
    }

    if (!username || typeof username !== 'string' || username.trim().length === 0) {
      res.status(400).json({ error: 'Username is required' });
      return;
    }

    const trimmedUsername = username.trim();
    if (trimmedUsername.length > 20) {
      res.status(400).json({ error: 'Username too long' });
      return;
    }

    // ── Rate limiting ───────────────────────────────────────────────────
    const ip = req.ip || req.headers['x-forwarded-for'] || 'unknown';
    const { allowed } = await checkUserMsgRateLimit(ip);

    if (!allowed) {
      res.status(429).json({
        error: 'Je stuurt berichten te snel. Wacht even.',
      });
      return;
    }

    // ── Write message ───────────────────────────────────────────────────
    await db.collection('chat_messages').add({
      username: trimmedUsername,
      text: trimmed,
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

    return null;
  });