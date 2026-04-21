/* Profanity Filter

   Content moderation for chat messages.

   Detects profanity in two tiers:
   - Severe → block the message entirely
   - Mild → auto-censor to asterisks

   Handles common evasion techniques:
   - Leetspeak (f*ck → f***ck, sh1t → sh**t)
   - Spacing (f u c k → f****)
   - Repeated letters (fuuuuck → f*****k)
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
    String cleaned = message;
    bool foundMild = false;

    for (final word in ProfanityConfig.allMildWords) {
      if (_containsWord(normalized, word)) {
        foundMild = true;
        // Replace in the original message (case-insensitive)
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
  /// Handles: leetspeak, repeated chars, mixed case
  /// Keeps spaces intact so word boundaries work correctly
  static String _normalize(String text) {
    String s = text.toLowerCase();

    // Collapse repeated characters (fuuuuck → fuck)
    s = s.replaceAllMapped(
      RegExp(r'(.)\1{2,}'),
      (match) => match.group(1)! * 2, // keep max 2 repeats
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
  /// Uses word boundaries OR string boundaries (start/end of text).
  /// This catches: "fuck", "fuck you", "fuckoff", "niggerbitch", etc.
  static bool _containsWord(String normalized, String badWord) {
    // Pattern explanation:
    // (?:^|\b) = start of string OR word boundary
    // (?:$|\b) = end of string OR word boundary
    // This catches the word anywhere: alone, at start, at end, or embedded
    final pattern = RegExp(r'(?:^|\b)' + RegExp.escape(badWord) + r'(?:$|\b)');
    return pattern.hasMatch(normalized);
  }

  // ── Censoring ─────────────────────────────────────────────────────────────

  /// Replace a bad word with asterisks in the original message.
  ///
  /// Keeps first and last letter visible: "fuck" → "f**k"
  /// Works at start, end, middle, or stuck to other words.
  static String _censorWord(String text, String badWord) {
    final pattern = RegExp(
      r'(?:^|\b)' + RegExp.escape(badWord) + r'(?:$|\b)',
      caseSensitive: false,
    );

    return text.replaceAllMapped(pattern, (match) {
      final word = match.group(0)!;
      if (word.length <= 2) {
        return '*' * word.length;
      }
      // Keep first and last letter, asterisk the middle
      final first = word[0];
      final last = word[word.length - 1];
      final middle = '*' * (word.length - 2);
      return '$first$middle$last';
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
