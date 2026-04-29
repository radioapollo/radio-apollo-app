/**
 * seed_profanity.js
 *
 * Reads the four hardcoded word lists out of
 *   lib/utils/profanity/profanity_config.dart
 * and writes them to Firestore at config/profanity, so the
 * radiostation can manage the lists from the Firebase Console.
 *
 * The dart file is parsed with a regex — we don't need a full Dart
 * parser, just to pull the string literals between the four list
 * declarations. This keeps the seed script in sync with whatever is
 * currently in the dart file at the time you run it.
 *
 * Usage (run from project root):
 *   node seed_profanity.js
 *
 * Re-running is safe: it overwrites the document. Any extra words
 * the radiostation has already added in the Console WILL BE LOST,
 * so only run this:
 *   - the first time (initial seed), or
 *   - after a deliberate hardcoded-list change you want pushed up
 *
 * Requirements:
 *   - serviceAccount.json in the same directory
 *   - npm install firebase-admin (already in your project)
 */

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

const CONFIG_PATH = path.join(
  __dirname,
  'lib',
  'utils',
  'profanity',
  'profanity_config.dart',
);

// ── Parser ──────────────────────────────────────────────────────────────────

/**
 * Extract the contents of a `static const List<String> NAME = [ ... ];`
 * declaration from the dart source. Comments inside the list (// ...)
 * are stripped before parsing the strings.
 */
function extractList(source, listName) {
  const pattern = new RegExp(
    `static\\s+const\\s+List<String>\\s+${listName}\\s*=\\s*\\[([\\s\\S]*?)\\];`,
    'm',
  );
  const match = source.match(pattern);
  if (!match) {
    throw new Error(`Could not find list "${listName}" in ${CONFIG_PATH}`);
  }

  const body = match[1];
  // Strip line comments
  const cleaned = body.replace(/\/\/[^\n]*/g, '');

  // Pull every single- or double-quoted string literal
  const stringRegex = /(?:'([^'\\]*(?:\\.[^'\\]*)*)'|"([^"\\]*(?:\\.[^"\\]*)*)")/g;
  const out = [];
  let m;
  while ((m = stringRegex.exec(cleaned)) !== null) {
    const value = m[1] !== undefined ? m[1] : m[2];
    // Unescape the few escapes we might see in word lists
    const unescaped = value
      .replace(/\\'/g, "'")
      .replace(/\\"/g, '"')
      .replace(/\\\\/g, '\\');
    out.push(unescaped);
  }
  return out;
}

/**
 * Lowercase, trim, dedupe, sort.
 */
function normalize(words) {
  const set = new Set();
  for (const w of words) {
    const clean = w.trim().toLowerCase();
    if (clean) set.add(clean);
  }
  return Array.from(set).sort();
}

// ── Main ────────────────────────────────────────────────────────────────────

async function run() {
  if (!fs.existsSync(CONFIG_PATH)) {
    console.error(`profanity_config.dart not found at:\n  ${CONFIG_PATH}`);
    console.error('Run this script from the project root.');
    process.exit(1);
  }

  const source = fs.readFileSync(CONFIG_PATH, 'utf8');

  console.log('Parsing profanity_config.dart...\n');

  const severeDutch = extractList(source, 'severeWordsDutch');
  const severeEnglish = extractList(source, 'severeWordsEnglish');
  const mildDutch = extractList(source, 'mildWordsDutch');
  const mildEnglish = extractList(source, 'mildWordsEnglish');

  console.log(`  severeWordsDutch:   ${severeDutch.length} entries`);
  console.log(`  severeWordsEnglish: ${severeEnglish.length} entries`);
  console.log(`  mildWordsDutch:     ${mildDutch.length} entries`);
  console.log(`  mildWordsEnglish:   ${mildEnglish.length} entries`);

  const severeWords = normalize([...severeDutch, ...severeEnglish]);
  const mildWords = normalize([...mildDutch, ...mildEnglish]);

  console.log(`\nMerged (deduped, sorted):`);
  console.log(`  severeWords: ${severeWords.length}`);
  console.log(`  mildWords:   ${mildWords.length}`);

  // ── Confirm before overwriting ────────────────────────────────────────────
  const ref = db.collection('config').doc('profanity');
  const existing = await ref.get();
  if (existing.exists) {
    const data = existing.data() || {};
    console.log(`\n⚠ config/profanity already exists with:`);
    console.log(`  severeWords: ${(data.severeWords || []).length} entries`);
    console.log(`  mildWords:   ${(data.mildWords || []).length} entries`);
    console.log(
      '\nThis script will OVERWRITE it. If the radiostation has added words ' +
      'via the Console, they will be lost. Press Ctrl+C to abort, or wait ' +
      '5 seconds to continue...',
    );
    await new Promise((r) => setTimeout(r, 5000));
  }

  // ── Write ─────────────────────────────────────────────────────────────────
  await ref.set({
    severeWords,
    mildWords,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  console.log('\n✓ Wrote config/profanity');
  console.log('  Edit it in the Firebase Console:');
  console.log('  Firestore → config → profanity → severeWords / mildWords');
  process.exit(0);
}

run().catch((err) => {
  console.error('Seed failed:', err);
  process.exit(1);
});