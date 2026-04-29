/* Profanity Filter

   Content moderation for chat messages.

   Detects profanity in two tiers:
   - Severe → block the message entirely
   - Mild   → auto-censor to asterisks

   Handles common evasion techniques:
   - Leetspeak (f@ck → f**k, sh1t → sh*t)
   - Spacing (f u c k → f**k)
   - Repeated letters (fuuuuck → f**k)
   - Mixed case (FuCk → F**k)

   Source of truth
   ───────────────
   The active word lists come from `ProfanityService`, which loads
   them from Firestore on startup and listens for live updates. The
   hardcoded lists in `ProfanityConfig` are always merged in as a
   fallback so the filter still works on first launch / offline /
   if Firestore is unreachable.

   Usage:
     final result = ProfanityFilter.check('Dit is kut');
     if (result.isSevere) {
       // Block message, show error
     } else if (result.hasMildProfanity) {
       // Send result.cleanedText instead of original
     } else {
       // Message is clean, send as-is
     }
*/

import 'profanity_service.dart';

class ProfanityFilter {
  ProfanityFilter._();

  /// Check a message for profanity and return a result object.
  static ProfanityCheckResult check(String message) {
    if (message.trim().isEmpty) {
      return ProfanityCheckResult.clean(message);
    }

    // Normalize the message for detection (but keep original for censoring)
    final normalized = _normalize(message);

    // Pull the live lists from the service. These already include the
    // hardcoded fallback so they're never empty.
    final severeWords = ProfanityService.instance.activeSevereWords;
    final mildWords = ProfanityService.instance.activeMildWords;

    // Check for severe words first (hard block)
    for (final word in severeWords) {
      if (_containsWord(normalized, word)) {
        return ProfanityCheckResult.severe(message);
      }
    }

    // Check for mild words (auto-censor)
    String cleaned = message; // Work with original message
    bool foundMild = false;

    for (final word in mildWords) {
      if (_containsWord(normalized, word)) {
        foundMild = true;
        // Censor in the ORIGINAL message with flexible pattern
        cleaned = _censorWord(cleaned, word);
      }
    }

    if (foundMild) {
      return ProfanityCheckResult.mild(cleaned);
    }

    return ProfanityCheckResult.clean(message);
  }

  // ── Normalization ─────────────────────────────────────────────────────────

  /// Normalize text for detection.
  ///
  /// Handles: leetspeak, repeated chars, spacing, mixed case
  static String _normalize(String text) {
    String s = text.toLowerCase();

    // Remove spaces between single characters (catches "f u c k")
    s = s.replaceAll(RegExp(r'\b(\w)\s+(?=\w\s|\w\b)'), r'$1');

    // Collapse repeated characters (fuuuuck → fuck)
    // Only collapse 3+ repeats to preserve normal words like "hallo", "een"
    s = s.replaceAllMapped(
      RegExp(r'(.)\1{2,}'),
      (match) => match.group(1)!, // keep only 1
    );

    // Leetspeak substitutions
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

  /// Check if normalized text contains a bad word.
  ///
  /// Uses word boundaries to match whole words only.
  static bool _containsWord(String normalized, String badWord) {
    // Check exact word
    final pattern = RegExp(r'\b' + RegExp.escape(badWord) + r'\b');
    if (pattern.hasMatch(normalized)) return true;

    // Also check common Dutch plurals
    final pluralPattern = RegExp(r'\b' + RegExp.escape(badWord) + r'(en|s)\b');
    if (pluralPattern.hasMatch(normalized)) return true;

    return false;
  }

  // ── Censoring ─────────────────────────────────────────────────────────────

  /// Replace a bad word with asterisks in the original message.
  ///
  /// Keeps first and last letter visible: "fuck" → "f**k"
  /// Handles variations in case and repeated letters.
  static String _censorWord(String text, String badWord) {
    // Build a flexible regex pattern that matches the badword with variations
    String pattern = '';

    for (int i = 0; i < badWord.length; i++) {
      final char = badWord[i];
      if (char.toLowerCase() != char.toUpperCase()) {
        // It's a letter - match both cases, 1-3 repeats
        pattern += '[${char.toUpperCase()}${char.toLowerCase()}]{1,3}';
      } else {
        // Not a letter - match as-is with optional repeats
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

class ProfanityCheckResult {
  final bool isSevere;
  final bool hasMildProfanity;
  final String cleanedText;

  const ProfanityCheckResult._({
    required this.isSevere,
    required this.hasMildProfanity,
    required this.cleanedText,
  });

  factory ProfanityCheckResult.clean(String text) =>
      ProfanityCheckResult._(
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

  factory ProfanityCheckResult.severe(String text) =>
      ProfanityCheckResult._(
        isSevere: true,
        hasMildProfanity: false,
        cleanedText: text,
      );
}