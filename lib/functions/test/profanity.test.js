/* Server-side profanity filter tests.

   This is the actual moderation boundary the chat depends on. The Flutter
   client also runs a filter for UX (immediate feedback in the input field),
   but the server's checkProfanity in userSendMessage is what stops a
   determined attacker who skips the client entirely.

   firebase-admin is mocked so checkProfanity falls back to the hardcoded
   FALLBACK_SEVERE_WORDS / FALLBACK_MILD_WORDS lists in profanity.js. The
   Firestore fetch in refreshFromFirestore() rejects, gets swallowed by
   the catch in getWordLists, and the cached fallback arrays are used.
   That gives us a stable wordlist to assert against without standing up
   the Firebase emulator.
*/

// firebase-admin needs to be mocked BEFORE require('../profanity') so the
// module's top-level admin reference is the mocked one.
jest.mock('firebase-admin', () => ({
  firestore: () => {
    throw new Error(
      'firebase-admin not initialised — expected in unit tests',
    );
  },
}));

const { checkProfanity, _resetProfanityCache } = require('../profanity');

beforeEach(() => {
  // Each test starts with an expired cache so the fallback path runs
  // every time and the assertions don't depend on inter-test state.
  _resetProfanityCache();
});

describe('checkProfanity — clean input', () => {
  test('clean Dutch text passes through unchanged', async () => {
    const result = await checkProfanity('Hallo allemaal, mooie show vandaag');
    expect(result.isSevere).toBe(false);
    expect(result.cleanedText).toBe('Hallo allemaal, mooie show vandaag');
  });

  test('empty string is clean', async () => {
    const result = await checkProfanity('');
    expect(result.isSevere).toBe(false);
    expect(result.cleanedText).toBe('');
  });

  test('common Dutch words that contain no profanity pass through', async () => {
    const result = await checkProfanity('Heel mooi nummer, bedankt!');
    expect(result.isSevere).toBe(false);
    expect(result.cleanedText).toBe('Heel mooi nummer, bedankt!');
  });
});

describe('checkProfanity — severe blocks', () => {
  // FALLBACK_SEVERE_WORDS includes 'mongool', 'klootzak', 'nigger',
  // 'kill yourself', 'kys', etc. Pick a sampling to verify behaviour.

  test('blocks slurs (severe list)', async () => {
    const result = await checkProfanity('je bent een mongool');
    expect(result.isSevere).toBe(true);
  });

  test('blocks slurs regardless of case', async () => {
    const result = await checkProfanity('je bent een MONGOOL');
    expect(result.isSevere).toBe(true);
  });

  test('blocks self-harm encouragement ("kys")', async () => {
    const result = await checkProfanity('go kys honestly');
    expect(result.isSevere).toBe(true);
  });

  test('blocks multi-word severe phrases ("kill yourself")', async () => {
    // After the normalize() whitespace-stripping fix, multi-word
    // entries like "kill yourself" match correctly because the
    // spaces in the input line up with the spaces in the wordlist.
    const result = await checkProfanity('just kill yourself man');
    expect(result.isSevere).toBe(true);
  });

  test('blocks across leet substitutions (4 → a, 1 → i)', async () => {
    // 'm0ng00l' normalises to 'mongool'.
    const result = await checkProfanity('m0ng00l');
    expect(result.isSevere).toBe(true);
  });

  test('blocks despite character stuttering ("mongoool")', async () => {
    // The normalizer collapses runs of 3+ identical chars to 2,
    // so "mongoool" → "mongool". This is the bypass attempt
    // attackers use first; pinning it.
    const result = await checkProfanity('mongoool');
    expect(result.isSevere).toBe(true);
  });
});

describe('checkProfanity — mild censoring', () => {
  // FALLBACK_MILD_WORDS includes 'shit', 'fuck', 'damn', 'kut', etc.

  test('censors a mild word but does not flag as severe', async () => {
    const result = await checkProfanity('oh shit nog drie minuten');
    expect(result.isSevere).toBe(false);
    // Censored output keeps first + last char, middle replaced with stars.
    expect(result.cleanedText).toContain('s**t');
    expect(result.cleanedText).not.toContain('shit');
  });

  test('preserves the surrounding text exactly', async () => {
    const result = await checkProfanity('What the fuck is going on');
    expect(result.isSevere).toBe(false);
    expect(result.cleanedText.startsWith('What the ')).toBe(true);
    expect(result.cleanedText.endsWith(' is going on')).toBe(true);
  });

  test('censors multiple mild words in one message', async () => {
    const result = await checkProfanity('oh shit, damn it');
    expect(result.isSevere).toBe(false);
    expect(result.cleanedText).not.toContain('shit');
    expect(result.cleanedText).not.toContain('damn');
  });
});

describe('checkProfanity — word boundaries', () => {
  // The single biggest source of false positives in a filter is
  // matching a profane WORD as a SUBSTRING of an innocent word.
  // The Cloud Function uses regex with \b boundaries to prevent this.

  test('does NOT match "ass" inside "passage"', async () => {
    // 'ass' is in FALLBACK_MILD_WORDS.
    const result = await checkProfanity('a beautiful passage');
    expect(result.isSevere).toBe(false);
    expect(result.cleanedText).toBe('a beautiful passage');
  });

  test('does NOT match "hell" inside "shell"', async () => {
    const result = await checkProfanity('we sell shell paint here');
    expect(result.isSevere).toBe(false);
    expect(result.cleanedText).toBe('we sell shell paint here');
  });

  test('does NOT match "kut" inside a benign Dutch word', async () => {
    // No common benign Dutch word contains "kut" verbatim, but for
    // future-proofing: any made-up substring containing "kut"
    // surrounded by letters should NOT match.
    const result = await checkProfanity('akuten verdraaiing');
    expect(result.isSevere).toBe(false);
  });

  test('DOES match a profane word when it stands alone', async () => {
    const result = await checkProfanity('ass');
    expect(result.cleanedText).not.toBe('ass');
  });
});

describe('checkProfanity — return shape', () => {
  test('always returns { isSevere, cleanedText }', async () => {
    const result = await checkProfanity('anything');
    expect(result).toHaveProperty('isSevere');
    expect(result).toHaveProperty('cleanedText');
    expect(typeof result.isSevere).toBe('boolean');
    expect(typeof result.cleanedText).toBe('string');
  });

  test('on severe match, cleanedText is the ORIGINAL message', async () => {
    // The server returns the original — the function blocks with a
    // 400 response anyway, but if a future consumer reads cleanedText
    // on a severe match it shouldn't get a partially censored string.
    const original = 'je bent een mongool';
    const result = await checkProfanity(original);
    expect(result.isSevere).toBe(true);
    expect(result.cleanedText).toBe(original);
  });
});