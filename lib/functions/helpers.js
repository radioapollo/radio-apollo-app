/* Cloud Functions — Shared helpers
   CORS, rate limiting, session tokens, and user message rate limiting.
*/

const admin = require('firebase-admin');
const crypto = require('crypto');

// Lazy getter — guarantees admin.initializeApp() has been called first
function getDb() {
  return admin.firestore();
}

// ─── Configuration ──────────────────────────────────────────────────────────

const ALLOWED_ORIGINS = [
  // 'https://your-web-domain.com',  // uncomment when you have a web version
];

const MAX_LOGIN_ATTEMPTS = 5;
const LOCKOUT_WINDOW_MS  = 5 * 60 * 1000;   // 5 minutes

const SESSION_TTL_MS     = 2 * 60 * 60 * 1000; // 2 hours

const USER_MSG_LIMIT     = 10;               // max messages per window
const USER_MSG_WINDOW_MS = 60 * 1000;        // 1 minute

// ─── CORS ───────────────────────────────────────────────────────────────────

function setCorsHeaders(req, res) {
  const origin = req.headers.origin;
  if (origin && (
    ALLOWED_ORIGINS.includes(origin) ||
    origin === 'http://localhost' ||
    origin.match(/^http:\/\/localhost:\d+$/)
  )) {
    res.set('Access-Control-Allow-Origin', origin);
  }
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type');
}

// ─── Login rate limiting (brute-force protection) ───────────────────────────

async function checkRateLimit(ip) {
  const db = getDb();
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

// ─── Admin session tokens ───────────────────────────────────────────────────

async function createSessionToken() {
  const db = getDb();
  const token = crypto.randomBytes(32).toString('hex');
  const expiresAt = new Date(Date.now() + SESSION_TTL_MS);

  await db.collection('_admin_sessions').doc(token).set({
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
  });

  return token;
}

async function validateSessionToken(token) {
  if (!token || typeof token !== 'string') return false;

  const db = getDb();
  const doc = await db.collection('_admin_sessions').doc(token).get();
  if (!doc.exists) return false;

  const data = doc.data();
  if (!data.expiresAt) return false;

  return data.expiresAt.toMillis() > Date.now();
}

// ─── User message rate limiting ─────────────────────────────────────────────

async function checkUserMsgRateLimit(ip) {
  const db = getDb();
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

module.exports = {
  ALLOWED_ORIGINS,
  MAX_LOGIN_ATTEMPTS,
  LOCKOUT_WINDOW_MS,
  SESSION_TTL_MS,
  USER_MSG_LIMIT,
  USER_MSG_WINDOW_MS,
  setCorsHeaders,
  checkRateLimit,
  recordFailedAttempt,
  clearRateLimit,
  createSessionToken,
  validateSessionToken,
  checkUserMsgRateLimit,
};