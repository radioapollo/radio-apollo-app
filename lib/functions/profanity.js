/* Profanity Filter — Cloud Functions

   Server-side enforcement of the chat profanity filter.

   The hardcoded SEVERE_WORDS / MILD_WORDS lists below are the
   safety net. The actual lists used at runtime are merged with
   the contents of `config/profanity` in Firestore, which the
   radiostation manages from the Firebase Console.

   Caching
   ───────
   We don't want to hit Firestore on every chat message — that
   would add ~30ms of latency and cost a read per message. Instead
   the merged lists are cached in module memory for 60 seconds.
   Cloud Functions instances stay warm for several minutes, so in
   practice most invocations hit the in-memory cache.

   When the radiostation adds a word in the console, it can take
   up to 60 seconds for the server to pick it up. The Flutter
   client picks it up immediately because it uses a snapshot
   listener — but the client check is only for instant UX, the
   server is the authoritative gate.

   Hardcoded lists
   ───────────────
   These are intentionally small. The goal isn't to duplicate the
   massive Flutter-side list — it's to have a "minimum viable
   filter" that still catches the most common cases if Firestore
   is unavailable. The full list lives in the client + Firestore.
*/

const admin = require('firebase-admin');

// ─── Hardcoded fallback lists ──────────────────────────────────────────────

const FALLBACK_SEVERE_WORDS = [
  'hoer', 'kankerlijer', 'kankerhond', 'mongool', 'mof', 'nikker',
  'tyfuslijer', 'kutwijf', 'teringlijder', 'klootzak', 'verkrachten', 'neuken',
  'nigger', 'nigga', 'faggot', 'retard', 'tranny', 'chink', 'spic',
  'rape', 'molest', 'kill yourself', 'kys',
];

const FALLBACK_MILD_WORDS = [
  'kut', 'shit', 'fuck', 'godverdomme', 'verdomme', 'klote', 'lul',
  'eikel', 'stom', 'debiel', 'idioot', 'sufkop',
  'damn', 'hell', 'ass', 'asshole', 'bitch', 'bastard',
  'crap', 'piss', 'dick', 'cock', 'pussy', 'whore', 'slut',
];

const LEET_MAP = {
  '0': 'o', '1': 'i', '3': 'e', '4': 'a', '5': 's',
  '7': 't', '8': 'b', '@': 'a', '$': 's', '!': 'i',
};

// ─── Firestore-backed list cache ───────────────────────────────────────────

const CACHE_TTL_MS = 60 * 1000;

let cachedSevere = [...FALLBACK_SEVERE_WORDS];
let cachedMild = [...FALLBACK_MILD_WORDS];
let cacheExpiresAt = 0;
let inFlightRefresh = null;

/**
 * Returns the active word lists, refreshing from Firestore if the
 * cache has expired. We coalesce concurrent refreshes so a burst of
 * messages right after expiry only triggers one Firestore read.
 */
async function getWordLists() {
  const now = Date.now();
  if (now < cacheExpiresAt) {
    return { severe: cachedSevere, mild: cachedMild };
  }

  if (!inFlightRefresh) {
    inFlightRefresh = refreshFromFirestore().finally(() => {
      inFlightRefresh = null;
    });
  }

  try {
    await inFlightRefresh;
  } catch (e) {
    // If Firestore is unreachable, keep using the cached (or fallback)
    // lists. We don't want chat moderation to break because of a
    // transient Firestore hiccup.
    console.warn('[profanity] Firestore refresh failed, using last known list:', e.message);
  }

  return { severe: cachedSevere, mild: cachedMild };
}

async function refreshFromFirestore() {
  const db = admin.firestore();
  const snap = await db.collection('config').doc('profanity').get();

  const data = snap.exists ? snap.data() : {};
  const remoteSevere = normalizeArray(data.severeWords);
  const remoteMild = normalizeArray(data.mildWords);

  // Merge fallback + remote, dedupe via Set
  cachedSevere = Array.from(new Set([...FALLBACK_SEVERE_WORDS, ...remoteSevere]));
  cachedMild = Array.from(new Set([...FALLBACK_MILD_WORDS, ...remoteMild]));
  cacheExpiresAt = Date.now() + CACHE_TTL_MS;

  console.log(
    `[profanity] Refreshed lists (severe: ${cachedSevere.length}, ` +
    `mild: ${cachedMild.length}, remote-extra: severe=${remoteSevere.length}, ` +
    `mild=${remoteMild.length})`,
  );
}

function normalizeArray(raw) {
  if (!Array.isArray(raw)) return [];
  const out = new Set();
  for (const item of raw) {
    if (typeof item !== 'string') continue;
    const clean = item.trim().toLowerCase();
    if (clean) out.add(clean);
  }
  return Array.from(out);
}

// ─── Filter logic ──────────────────────────────────────────────────────────

function escapeRegExp(s) {
  return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function normalize(text) {
  let s = text.toLowerCase().replace(/\s+/g, '').replace(/(.)\1{2,}/g, '$1$1');
  for (const [leet, normal] of Object.entries(LEET_MAP)) {
    s = s.replace(new RegExp(escapeRegExp(leet), 'g'), normal);
  }
  return s;
}

function containsWord(normalized, badWord) {
  const regex = new RegExp(`(?:^|\\b)${escapeRegExp(badWord)}(?:$|\\b)`);
  return regex.test(normalized);
}

function censorWord(text, badWord) {
  const regex = new RegExp(
    `(?:^|\\b)${escapeRegExp(badWord)}(?:$|\\b)`,
    'gi',
  );
  return text.replace(regex, (match) => {
    if (match.length <= 2) return '*'.repeat(match.length);
    return match[0] + '*'.repeat(match.length - 2) + match[match.length - 1];
  });
}

/**
 * Async profanity check. Awaits the list fetch (cached after the
 * first call) and then runs the same detection logic as before.
 */
async function checkProfanity(message) {
  const { severe, mild } = await getWordLists();
  const normalized = normalize(message);

  for (const word of severe) {
    if (containsWord(normalized, word)) {
      return { isSevere: true, cleanedText: message };
    }
  }

  let cleaned = message;
  for (const word of mild) {
    if (containsWord(normalized, word)) {
      cleaned = censorWord(cleaned, word);
    }
  }
  return { isSevere: false, cleanedText: cleaned };
}

module.exports = {
  checkProfanity,
  // Exported for tests / future Firestore trigger that invalidates the cache:
  _resetProfanityCache: () => { cacheExpiresAt = 0; },
};