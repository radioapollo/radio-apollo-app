/* Cloud Functions — Shared helpers
   CORS, rate limiting, session tokens, user message rate limiting, App Check.
*/

const admin = require('firebase-admin');
const crypto = require('crypto');

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

const USER_MSG_LIMIT     = 10;
const USER_MSG_WINDOW_MS = 60 * 1000;

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
  res.set('Access-Control-Allow-Headers', 'Content-Type, X-Firebase-AppCheck');
}

// ─── Trusted client IP ──────────────────────────────────────────────────────

function getClientIp(req) {
  return req.ip || 'unknown';
}

// ─── App Check verification ─────────────────────────────────────────────────

async function verifyAppCheck(req) {
  const token = req.header('X-Firebase-AppCheck');
  if (!token) return false;
  try {
    await admin.appCheck().verifyToken(token);
    return true;
  } catch (_) {
    return false;
  }
}

// ─── Login rate limiting (atomic) ──────────────────────────────────────────
//
// Atomically reads the current attempt count for this IP, increments it
// (or resets if outside the window), and decides whether the request is
// locked out. Doing this in a transaction prevents racing requests from
// all reading the same stale counter value — which was a TOCTOU bug in
// the previous separate-read-then-write design.
//
// Returns { locked, attempts, ref } where:
//   locked   - true if the request must be rejected with 429
//   attempts - the new count after this attempt is recorded
//   ref      - Firestore document reference, for clearRateLimit() on success
//
// This counts EVERY attempt, including the one that ultimately
// succeeds. The caller should call clearRateLimit(ref) on success
// so legitimate users aren't penalised.

async function checkAndIncrementLoginAttempt(ip) {
  const db = getDb();
  const ref = db.collection('_rate_limits').doc(ip);

  const result = await db.runTransaction(async (tx) => {
    const doc = await tx.get(ref);
    const now = Date.now();
    const windowStart = now - LOCKOUT_WINDOW_MS;

    let attempts = 0;

    if (doc.exists) {
      const data = doc.data();
      const last = data.lastAttempt ? data.lastAttempt.toMillis() : 0;
      if (last >= windowStart) {
        attempts = data.attempts || 0;
      }
      // else: window expired, treat as 0
    }

    // Already at the limit? Lock out without incrementing further.
    if (attempts >= MAX_LOGIN_ATTEMPTS) {
      return { locked: true, attempts };
    }

    const newAttempts = attempts + 1;
    tx.set(ref, {
      attempts: newAttempts,
      lastAttempt: admin.firestore.Timestamp.fromMillis(now),
    });

    return { locked: false, attempts: newAttempts };
  });

  return { ...result, ref };
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
//
// Same atomic-transaction pattern as login rate limiting. Returns a plain
// boolean: true if the call may proceed, false if the bucket is over its
// USER_MSG_LIMIT for the current window.

async function checkUserMsgRateLimit(bucketKey) {
  const db = getDb();
  const ref = db.collection('_user_msg_limits').doc(bucketKey);

  return await db.runTransaction(async (tx) => {
    const doc = await tx.get(ref);
    const now = Date.now();

    if (!doc.exists) {
      tx.set(ref, {
        count: 1,
        windowStart: admin.firestore.Timestamp.fromMillis(now),
      });
      return true;
    }

    const data = doc.data();
    const windowStartMs = data.windowStart.toMillis();

    // Window expired — reset
    if (now - windowStartMs > USER_MSG_WINDOW_MS) {
      tx.set(ref, {
        count: 1,
        windowStart: admin.firestore.Timestamp.fromMillis(now),
      });
      return true;
    }

    // Still within window
    if (data.count >= USER_MSG_LIMIT) {
      return false;
    }

    tx.update(ref, {
      count: admin.firestore.FieldValue.increment(1),
    });
    return true;
  });
}

module.exports = {
  ALLOWED_ORIGINS,
  MAX_LOGIN_ATTEMPTS,
  LOCKOUT_WINDOW_MS,
  SESSION_TTL_MS,
  USER_MSG_LIMIT,
  USER_MSG_WINDOW_MS,
  setCorsHeaders,
  getClientIp,
  verifyAppCheck,
  checkAndIncrementLoginAttempt,
  clearRateLimit,
  createSessionToken,
  validateSessionToken,
  checkUserMsgRateLimit,
};