const functions = require('firebase-functions');
const admin = require('firebase-admin');
const bcrypt = require('bcrypt');

admin.initializeApp();
const db = admin.firestore();

// ─── Configuration ──────────────────────────────────────────────────────────

// Allowed origins — add your web domain here if you ever host a web version.
// For a mobile-only app, we can be restrictive.
const ALLOWED_ORIGINS = ['http://localhost'
  // 'https://your-web-domain.com',  // uncomment when you have a web version
];

const MAX_LOGIN_ATTEMPTS = 5;           // max failed attempts before lockout
const LOCKOUT_WINDOW_MS = 5 * 60 * 1000; // 5 minutes

// ─── Helpers ────────────────────────────────────────────────────────────────

/**
 * Sets restrictive CORS headers.
 * For a mobile-only app this effectively blocks browser-based attacks.
 */
function setCorsHeaders(req, res) {
  const origin = req.headers.origin;
  if (origin && (
    ALLOWED_ORIGINS.includes(origin) ||
    origin.startsWith('http://localhost:')
  )) {
    res.set('Access-Control-Allow-Origin', origin);
  }
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type');
}

/**
 * Checks whether the given IP is currently locked out.
 * Returns { locked: bool, attemptsDoc: Firestore doc ref }
 */
async function checkRateLimit(ip) {
  const ref = db.collection('_rate_limits').doc(ip);
  const doc = await ref.get();

  if (!doc.exists) {
    return { locked: false, ref, attempts: 0 };
  }

  const data = doc.data();
  const windowStart = Date.now() - LOCKOUT_WINDOW_MS;

  // If the lockout window has passed, reset
  if (data.lastAttempt.toMillis() < windowStart) {
    await ref.delete();
    return { locked: false, ref, attempts: 0 };
  }

  // Still within the window — check attempt count
  if (data.attempts >= MAX_LOGIN_ATTEMPTS) {
    return { locked: true, ref, attempts: data.attempts };
  }

  return { locked: false, ref, attempts: data.attempts };
}

/**
 * Records a failed login attempt for the given IP.
 */
async function recordFailedAttempt(ref, currentAttempts) {
  await ref.set({
    attempts: currentAttempts + 1,
    lastAttempt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

/**
 * Clears rate limit tracking for the given IP after a successful login.
 */
async function clearRateLimit(ref) {
  await ref.delete();
}

// ─── Admin Login (with rate limiting) ───────────────────────────────────────

exports.adminLogin = functions.region('europe-west1').https.onRequest(async (req, res) => {
  setCorsHeaders(req, res);

  // Handle preflight
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

    // Success — clear any tracked attempts
    await clearRateLimit(ref);
    res.status(200).json({ success: true });

  } catch (e) {
    console.error(e);
    res.status(500).json({ error: 'Internal error' });
  }
});

// ─── Admin Send Message ─────────────────────────────────────────────────────
//
// This endpoint lets the admin send chat messages server-side so that
// the client never writes role:'admin' directly to Firestore.

exports.adminSendMessage = functions.region('europe-west1').https.onRequest(async (req, res) => {
  setCorsHeaders(req, res);

  // Handle preflight
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  try {
    const { password, text } = req.body;

    // ── Validate inputs ─────────────────────────────────────────────────
    if (!password) {
      res.status(400).json({ error: 'Password is required' });
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

    // ── Rate limiting (reuse the same mechanism) ────────────────────────
    const ip = req.ip || req.headers['x-forwarded-for'] || 'unknown';
    const { locked, ref, attempts } = await checkRateLimit(ip);

    if (locked) {
      res.status(429).json({
        error: 'Te veel pogingen. Probeer het over 5 minuten opnieuw.',
      });
      return;
    }

    // ── Verify admin password ───────────────────────────────────────────
    const configDoc = await db.collection('config').doc('admin').get();

    if (!configDoc.exists) {
      res.status(404).json({ error: 'Admin config not found' });
      return;
    }

    const match = await bcrypt.compare(password, configDoc.data().passwordHash);

    if (!match) {
      await recordFailedAttempt(ref, attempts);
      res.status(401).json({ error: 'Invalid password' });
      return;
    }

    await clearRateLimit(ref);

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

// ─── Scheduled Cleanup: delete messages & usernames older than 24 hours ─────
//
// Runs every hour. Deletes chat_messages where timestamp > 24h ago,
// and usernames where claimedAt > 24h ago.

exports.cleanupOldData = functions
  .region('europe-west1')
  .pubsub.schedule('every 1 hours')
  .timeZone('Europe/Brussels')
  .onRun(async (_context) => {
    const cutoff = new Date(Date.now() - 24 * 60 * 60 * 1000);

    const collections = [
      { name: 'chat_messages', field: 'timestamp' },
      { name: 'usernames',     field: 'claimedAt'  },
    ];

    for (const { name, field } of collections) {
      const snapshot = await db
        .collection(name)
        .where(field, '<', cutoff)
        .get();

      if (snapshot.empty) {
        console.log(`No old documents in ${name}.`);
        continue;
      }

      // Firestore batches are limited to 500 operations
      const batches = [];
      let batch = db.batch();
      let count = 0;

      snapshot.docs.forEach((doc) => {
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

      console.log(`Deleted ${count} old documents from ${name}.`);
    }

    return null;
  });