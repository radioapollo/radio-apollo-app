/* Profanity Configuration

   Word lists for content moderation in the chat.

   Two severity tiers:
   - SEVERE: Slurs, hate speech, extreme vulgarity → hard block
   - MILD: Common profanity, crude language → auto-censor to asterisks

   Two languages: Dutch + English

   Update this file to add/remove words as your community needs evolve.
*/

class ProfanityConfig {
  ProfanityConfig._();

  // ── SEVERE WORDS ─────────────────────────────────────────────────────────
  //
  // These trigger instant message rejection. Include slurs, hate speech,
  // extreme sexual/violent language, and anything that should never appear.

  static const List<String> severeWordsDutch = [
    // Slurs and hate speech
    'hoer',
    'kankerlijer',
    'kankerhond',
    'mongool',
    'mof',
    'nikker',
    'tyfuslijer',

    // Extreme vulgarity
    'kutwijf',
    'teringlijder',
    'klootzak',

    // Sexual/violent (extreme)
    'verkrachten',
    'neuken',
  ];

  static const List<String> severeWordsEnglish = [
    // Slurs (racial, ethnic, homophobic, ableist)
    'nigger',
    'nigga',
    'faggot',
    'retard',
    'tranny',
    'chink',
    'spic',

    // Extreme sexual/violent
    'rape',
    'molest',

    // Hate speech patterns
    'kill yourself',
    'kys',
  ];

  // ── MILD WORDS ───────────────────────────────────────────────────────────
  //
  // These get auto-censored to asterisks but the message still goes through.
  // Common swear words, crude language that's vulgar but not hateful.

  static const List<String> mildWordsDutch = [
    'kut',
    'shit',
    'fuck',
    'godverdomme',
    'verdomme',
    'klote',
    'lul',
    'eikel',
    'stom',
    'debiel',
    'idioot',
    'sufkop',
  ];

  static const List<String> mildWordsEnglish = [
    'fuck',
    'shit',
    'damn',
    'hell',
    'ass',
    'asshole',
    'bitch',
    'bastard',
    'crap',
    'piss',
    'dick',
    'cock',
    'pussy',
    'whore',
    'slut',
  ];

  // ── COMBINED LISTS ───────────────────────────────────────────────────────

  static List<String> get allSevereWords => [
    ...severeWordsDutch,
    ...severeWordsEnglish,
  ];

  static List<String> get allMildWords => [
    ...mildWordsDutch,
    ...mildWordsEnglish,
  ];
}
