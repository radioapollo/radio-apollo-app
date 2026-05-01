/* Profanity Filter

   Content moderation for chat messages.

   Detects profanity in two tiers:
   - Severe → block the message entirely
   - Mild   → auto-censor to asterisks

   Source of truth
   ───────────────
   Word lists come from ProfanityService, which loads them from
   Firestore on startup and listens for live updates. The hardcoded
   ProfanityConfig lists are merged in as a fallback so the filter
   works on first launch / offline / if Firestore is unreachable.

   ProfanityCheckResult lives at the bottom of this file. If your
   project already has it elsewhere, delete that section.
*/

import 'profanity_service.dart';

class ProfanityFilter {
  ProfanityFilter._();

  /// Check a message for profanity and return a result object.
  static ProfanityCheckResult check(String message) {
    if (message.trim().isEmpty) {
      return ProfanityCheckResult.clean(message);
    }

    final normalized = _normalize(message);

    // Live merged lists (hardcoded fallback + Firestore additions).
    final severeWords = ProfanityService.instance.activeSevereWords;
    final mildWords = ProfanityService.instance.activeMildWords;

    for (final word in severeWords) {
      if (_containsWord(normalized, word)) {
        return ProfanityCheckResult.severe(message);
      }
    }

    String cleaned = message;
    bool foundMild = false;

    for (final word in mildWords) {
      if (_containsWord(normalized, word)) {
        foundMild = true;
        cleaned = _censorWord(cleaned, word);
      }
    }

    if (foundMild) {
      return ProfanityCheckResult.mild(cleaned);
    }

    return ProfanityCheckResult.clean(message);
  }

  // ── Normalization ─────────────────────────────────────────────────────────

  static String _normalize(String text) {
    String s = text.toLowerCase();

    s = s.replaceAll(RegExp(r'\b(\w)\s+(?=\w\s|\w\b)'), r'$1');

    s = s.replaceAllMapped(RegExp(r'(.)\1{2,}'), (match) => match.group(1)!);

    final leetMap = {
      '0': 'o',
      '1': 'i',
      '3': 'e',
      '4': 'a',
      '5': 's',
      '7': 't',
      '8': 'b',
      '@': 'a',
      r'$': 's',
      '!': 'i',
    };

    leetMap.forEach((leet, normal) {
      s = s.replaceAll(leet, normal);
    });

    return s;
  }

  // ── Detection ─────────────────────────────────────────────────────────────

  static bool _containsWord(String normalized, String badWord) {
    final pattern = RegExp(r'\b' + RegExp.escape(badWord) + r'\b');
    if (pattern.hasMatch(normalized)) return true;

    final pluralPattern = RegExp(r'\b' + RegExp.escape(badWord) + r'(en|s)\b');
    if (pluralPattern.hasMatch(normalized)) return true;

    return false;
  }

  // ── Censoring ─────────────────────────────────────────────────────────────

  static String _censorWord(String text, String badWord) {
    String pattern = '';

    for (int i = 0; i < badWord.length; i++) {
      final char = badWord[i];
      if (char.toLowerCase() != char.toUpperCase()) {
        pattern += '[${char.toUpperCase()}${char.toLowerCase()}]{1,3}';
      } else {
        pattern += RegExp.escape(char) + '{1,3}';
      }
    }

    final regex = RegExp(r'\b' + pattern + r'\b');

    return text.replaceAllMapped(regex, (match) {
      final word = match.group(0)!;
      if (word.length <= 2) return '*' * word.length;
      return word[0] + '*' * (word.length - 2) + word[word.length - 1];
    });
  }
}

// ── Result ──────────────────────────────────────────────────────────────────
// If your project already defines ProfanityCheckResult somewhere else,
// delete this section and add the appropriate import at the top.

class ProfanityCheckResult {
  final bool isSevere;
  final bool hasMildProfanity;
  final String cleanedText;

  const ProfanityCheckResult._({
    required this.isSevere,
    required this.hasMildProfanity,
    required this.cleanedText,
  });

  factory ProfanityCheckResult.clean(String text) => ProfanityCheckResult._(
    isSevere: false,
    hasMildProfanity: false,
    cleanedText: text,
  );

  factory ProfanityCheckResult.mild(String cleanedText) =>
      ProfanityCheckResult._(
        isSevere: false,
        hasMildProfanity: true,
        cleanedText: cleanedText,
      );

  factory ProfanityCheckResult.severe(String text) => ProfanityCheckResult._(
    isSevere: true,
    hasMildProfanity: false,
    cleanedText: text,
  );
}
