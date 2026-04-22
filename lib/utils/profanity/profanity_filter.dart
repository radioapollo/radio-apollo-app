/* Profanity Filter - FINAL CORRECTED VERSION

   Content moderation for chat messages.

   Detects profanity in two tiers:
   - Severe → block the message entirely
   - Mild → auto-censor to asterisks

   Handles common evasion techniques:
   - Leetspeak (f@ck → f**k, sh1t → sh*t)
   - Spacing (f u c k → f**k)
   - Repeated letters (fuuuuck → f**k)
   - Mixed case (FuCk → F**k)

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

import 'profanity_config.dart';

class ProfanityFilter {
  ProfanityFilter._();

  /// Check a message for profanity and return a result object.
  static ProfanityCheckResult check(String message) {
    if (message.trim().isEmpty) {
      return ProfanityCheckResult.clean(message);
    }

    // Normalize the message for detection (but keep original for censoring)
    final normalized = _normalize(message);

    // Check for severe words first (hard block)
    for (final word in ProfanityConfig.allSevereWords) {
      if (_containsWord(normalized, word)) {
        return ProfanityCheckResult.severe(message);
      }
    }

    // Check for mild words (auto-censor)
    String cleaned = message; // Work with original message
    bool foundMild = false;

    for (final word in ProfanityConfig.allMildWords) {
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
    // Escape the badWord and use word boundaries
    final pattern = RegExp(r'\b' + RegExp.escape(badWord) + r'\b');
    return pattern.hasMatch(normalized);
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
      return word[0] + ('*' * (word.length - 2)) + word[word.length - 1];
    });
  }
}

// ── Result object ────────────────────────────────────────────────────────────

class ProfanityCheckResult {
  final String cleanedText;
  final bool isSevere;
  final bool hasMildProfanity;

  const ProfanityCheckResult._({
    required this.cleanedText,
    required this.isSevere,
    required this.hasMildProfanity,
  });

  factory ProfanityCheckResult.clean(String text) {
    return ProfanityCheckResult._(
      cleanedText: text,
      isSevere: false,
      hasMildProfanity: false,
    );
  }

  factory ProfanityCheckResult.severe(String originalText) {
    return ProfanityCheckResult._(
      cleanedText: originalText,
      isSevere: true,
      hasMildProfanity: false,
    );
  }

  factory ProfanityCheckResult.mild(String censoredText) {
    return ProfanityCheckResult._(
      cleanedText: censoredText,
      isSevere: false,
      hasMildProfanity: true,
    );
  }

  bool get isClean => !isSevere && !hasMildProfanity;
}
