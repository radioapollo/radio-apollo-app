const functions = require('firebase-functions');
const admin = require('firebase-admin');
const bcrypt = require('bcrypt');
const crypto = require('crypto');

admin.initializeApp();
const db = admin.firestore();

// ─── Configuration ──────────────────────────────────────────────────────────

const ALLOWED_ORIGINS = ['http://localhost'
  // 'https://your-web-domain.com',  // uncomment when you have a web version
];

const MAX_LOGIN_ATTEMPTS = 5;
const LOCKOUT_WINDOW_MS  = 5 * 60 * 1000;   // 5 minutes

const SESSION_TTL_MS     = 2 * 60 * 60 * 1000; // 2 hours

const USER_MSG_LIMIT     = 10;               // max messages per window
const USER_MSG_WINDOW_MS = 60 * 1000;        // 1 minute

// ─── Helpers ────────────────────────────────────────────────────────────────

function setCorsHeaders(req, res) {
  const origin = req.headers.origin;
  if (origin && (
    ALLOWED_ORIGINS.includes(origin) ||
    origin.startsWith('http://localhost:') ||
    origin === 'http://localhost'
  )) {
    res.set('Access-Control-Allow-Origin', origin);
  }
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type');
}

// ── Rate limiting (login brute-force protection) ────────────────────────────

async function checkRateLimit(ip) {
  const ref = db.collection('_rate_limits').doc(ip);
  const doc = await ref.get();

  if (!doc.exists) {
    return { locked: false, ref, attempts: 0 };
  }

  const data = doc.data();
  const windowStart = Date.now() - LOCKOUT_WINDOW_MS;

  if (data.lastAttempt.toMillis() < windowStart) {
    await ref.delete();
    return { locked: false, ref, attempts: 0 };
  }

  if (data.attempts >= MAX_LOGIN_ATTEMPTS) {
    return { locked: true, ref, attempts: data.attempts };
  }

  return { locked: false, ref, attempts: data.attempts };
}

async function recordFailedAttempt(ref, currentAttempts) {
  await ref.set({
    attempts: currentAttempts + 1,
    lastAttempt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

async function clearRateLimit(ref) {
  await ref.delete();
}

// ── Admin session tokens ────────────────────────────────────────────────────

/**
 * Generates a secure random token, stores it in Firestore with an expiry,
 * and returns the token string.
 */
async function createSessionToken() {
  const token = crypto.randomBytes(32).toString('hex');
  const expiresAt = new Date(Date.now() + SESSION_TTL_MS);

  await db.collection('_admin_sessions').doc(token).set({
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
  });

  return token;
}

/**
 * Validates a session token. Returns true if valid and not expired.
 */
async function validateSessionToken(token) {
  if (!token || typeof token !== 'string') return false;

  const doc = await db.collection('_admin_sessions').doc(token).get();
  if (!doc.exists) return false;

  const data = doc.data();
  if (!data.expiresAt) return false;

  return data.expiresAt.toMillis() > Date.now();
}

// ── User message rate limiting ──────────────────────────────────────────────

/**
 * Checks whether the given IP has exceeded the user message rate limit.
 * Returns { allowed: bool }.
 */
async function checkUserMsgRateLimit(ip) {
  const ref = db.collection('_user_msg_limits').doc(ip);
  const doc = await ref.get();

  if (!doc.exists) {
    await ref.set({
      count: 1,
      windowStart: admin.firestore.FieldValue.serverTimestamp(),
    });
    return { allowed: true };
  }

  const data = doc.data();
  const windowStartMs = data.windowStart.toMillis();

  // Window expired — reset
  if (Date.now() - windowStartMs > USER_MSG_WINDOW_MS) {
    await ref.set({
      count: 1,
      windowStart: admin.firestore.FieldValue.serverTimestamp(),
    });
    return { allowed: true };
  }

  // Still within window
  if (data.count >= USER_MSG_LIMIT) {
    return { allowed: false };
  }

  await ref.update({
    count: admin.firestore.FieldValue.increment(1),
  });
  return { allowed: true };
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
      .get();

    if (!msgSnap.empty) {
      const batches = [];
      let batch = db.batch();
      let count = 0;

      msgSnap.docs.forEach((doc) => {
        batch.delete(doc.ref);
        count++;
        if (count % 500 === 0) {
          batches.push(batch);
          batch = db.batch();
        }
      });
      batches.push(batch);

      for (const b of batches) {
        await b.commit();
      }
      console.log(`Deleted ${count} old chat messages.`);
    } else {
      console.log('No old chat messages.');
    }

    // ── Expired admin sessions ────────────────────────────────────────
    const sessionSnap = await db
      .collection('_admin_sessions')
      .where('expiresAt', '<', now)
      .get();

    if (!sessionSnap.empty) {
      let batch = db.batch();
      let count = 0;

      sessionSnap.docs.forEach((doc) => {
        batch.delete(doc.ref);
        count++;
        if (count % 500 === 0) {
          batch.commit();
          batch = db.batch();
        }
      });
      await batch.commit();
      console.log(`Deleted ${count} expired admin sessions.`);
    }

    // ── Expired user message rate limit records ───────────────────────
    const rateCutoff = new Date(Date.now() - USER_MSG_WINDOW_MS * 2);
    const rateSnap = await db
      .collection('_user_msg_limits')
      .where('windowStart', '<', rateCutoff)
      .get();

    if (!rateSnap.empty) {
      let batch = db.batch();
      let count = 0;

      rateSnap.docs.forEach((doc) => {
        batch.delete(doc.ref);
        count++;
        if (count % 500 === 0) {
          batch.commit();
          batch = db.batch();
        }
      });
      await batch.commit();
      console.log(`Deleted ${count} expired user rate limit records.`);
    }

    return null;
  });