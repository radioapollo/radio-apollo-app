/* Cloud Functions — Shared helpers
   CORS, App Check, IP detection, atomic rate limiting, session tokens.
*/

const admin = require('firebase-admin');
const crypto = require('crypto');

function getDb() {
  return admin.firestore();
}

// ─── Configuration ──────────────────────────────────────────────────────────

const ALLOWED_ORIGINS = [];

const MAX_LOGIN_ATTEMPTS = 5;
const LOCKOUT_WINDOW_MS  = 5 * 60 * 1000;

const SESSION_TTL_MS = 2 * 60 * 60 * 1000;

// Normal user message rate limit (App Check verified callers)
const USER_MSG_LIMIT     = 10;
const USER_MSG_WINDOW_MS = 60 * 1000;

// Strict rate limit for unattested callers (Xiaomi/HyperOS users with
// broken Play Integrity, plus any spam scripts). 2 per 30s = fine for
// human typing, painful for automation.
const USER_MSG_LIMIT_STRICT     = 2;
const USER_MSG_WINDOW_MS_STRICT = 30 * 1000;

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
//
// On Cloud Functions, every real request passes through Google's
// load balancer, which appends the real client IP to the right-hand
// end of X-Forwarded-For:
//
//   X-Forwarded-For: <attacker-supplied>, <attacker-supplied>, REAL_CLIENT_IP
//
// The leftmost entries can be anything the caller put there. Express's
// `req.ip` returns the LEFTMOST value when `trust proxy` is enabled
// (which Cloud Functions enables by default), so it IS spoofable.
//
// We read the rightmost entry of X-Forwarded-For instead. That's the
// only value Google itself wrote and the only one we can trust for
// security decisions like rate-limit bucketing.

function getClientIp(req) {
  const xff = req.headers['x-forwarded-for'];
  if (typeof xff === 'string' && xff.length > 0) {
    const parts = xff.split(',').map((s) => s.trim()).filter(Boolean);
    if (parts.length > 0) return parts[parts.length - 1];
  }
  // Fallback: the immediate connection IP (Google's load balancer).
  // Not ideal, but better than 'unknown' — and this branch should
  // basically never run in production.
  return req.socket?.remoteAddress || 'unknown';
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
// Read and increment in a single Firestore transaction so racing requests
// can't all read the same stale counter and slip through.

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
    }

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

// ─── User message rate limiting (atomic) ───────────────────────────────────

async function _checkUserMsgRate(bucketKey, limit, windowMs) {
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

    if (now - windowStartMs > windowMs) {
      tx.set(ref, {
        count: 1,
        windowStart: admin.firestore.Timestamp.fromMillis(now),
      });
      return true;
    }

    if (data.count >= limit) return false;

    tx.update(ref, { count: admin.firestore.FieldValue.increment(1) });
    return true;
  });
}

async function checkUserMsgRateLimit(bucketKey) {
  return _checkUserMsgRate(bucketKey, USER_MSG_LIMIT, USER_MSG_WINDOW_MS);
}

async function checkUserMsgRateLimitStrict(bucketKey) {
  return _checkUserMsgRate(
    bucketKey,
    USER_MSG_LIMIT_STRICT,
    USER_MSG_WINDOW_MS_STRICT,
  );
}

module.exports = {
  ALLOWED_ORIGINS,
  MAX_LOGIN_ATTEMPTS,
  LOCKOUT_WINDOW_MS,
  SESSION_TTL_MS,
  USER_MSG_LIMIT,
  USER_MSG_WINDOW_MS,
  USER_MSG_LIMIT_STRICT,
  USER_MSG_WINDOW_MS_STRICT,
  setCorsHeaders,
  getClientIp,
  verifyAppCheck,
  checkAndIncrementLoginAttempt,
  clearRateLimit,
  createSessionToken,
  validateSessionToken,
  checkUserMsgRateLimit,
  checkUserMsgRateLimitStrict,
};