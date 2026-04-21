// ═══════════════════════════════════════════════════════════════════════════
// Profanity Filter — Server-Side Enforcement
// ═══════════════════════════════════════════════════════════════════════════
//
// Add this section to your existing functions/index.js file.
//
// This validates ALL messages before they're stored in Firestore. The client
// also checks (for instant feedback), but the server is the real enforcement.
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
  const regex = new RegExp(`\\b${badWord.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\b`);
  return regex.test(normalized);
}

/**
 * Replace a bad word with asterisks in the original text.
 * Keeps first and last letter: "fuck" → "f**k"
 */
function censorWord(text, badWord) {
  const regex = new RegExp(`\\b${badWord.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\b`, 'gi');
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

// ═══════════════════════════════════════════════════════════════════════════
// Integration with existing userSendMessage function
// ═══════════════════════════════════════════════════════════════════════════
//
// Find your existing userSendMessage function in functions/index.js.
// Add the profanity check BEFORE the line that writes to Firestore.
//
// BEFORE (old code):
//
//     await db.collection('chat_messages').add({
//       username: trimmedUsername,
//       text: trimmed,
//       role: 'user',
//       timestamp: admin.firestore.FieldValue.serverTimestamp(),
//     });
//
// AFTER (new code with filter):
//
//     // ── Profanity check ─────────────────────────────────────────────────
//     const filterResult = checkProfanity(trimmed);
//     
//     if (filterResult.isSevere) {
//       res.status(400).json({
//         error: 'Dit bericht kan niet worden verzonden. Blijf vriendelijk.',
//       });
//       return;
//     }
//     
//     // Use censored text if mild profanity was detected
//     const textToStore = filterResult.cleanedText;
//     
//     // ── Write message ───────────────────────────────────────────────────
//     await db.collection('chat_messages').add({
//       username: trimmedUsername,
//       text: textToStore,
//       role: 'user',
//       timestamp: admin.firestore.FieldValue.serverTimestamp(),
//     });
//
// That's it. The server now rejects severe messages and auto-censors mild ones.
