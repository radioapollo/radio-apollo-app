/* Unit tests for pure-logic helpers.

   These tests exercise the date/time utilities (AppDateUtils), the
   day-shifting logic (ProgramService.getShiftedDays), the Event model
   getters, and the profanity filter (ProfanityFilter).

   All functions tested here are pure Dart — no Firebase, no platform
   channels — so they run quickly under plain `flutter test` with no
   setup.

   Bug-history note
   ────────────────
   Bug #1 in production was "Programmaschema shows wrong day". The
   root cause turned out to be in stream caching (broadcast streams
   don't replay), not in the day-shifting math — but the math is the
   spec, and getting it wrong would also produce a wrong-day display.
   The getShiftedDays test below pins the invariant: today must
   always sit at the requested index, on every weekday of the year.

   Why getShiftedDays is tested via re-implementation
   ──────────────────────────────────────────────────
   ProgramService instantiates FirebaseFirestore.instance in its
   constructor, so we can't construct it in a unit test without
   booting Firebase. The shift math itself doesn't touch Firestore —
   it only uses DateTime.now() and AppDateUtils.shiftList — so we
   exercise the same logic directly. If ProgramService is ever
   refactored to make _db lazy or injectable, replace
   shiftedDaysFor(...) below with a direct call to
   ProgramService().getShiftedDays(...).

   Security note
   ─────────────
   The ProfanityFilter tests verify CLIENT-SIDE behaviour. The actual
   security boundary is the userSendMessage Cloud Function, which runs
   its own profanity check on the server. See
   lib/functions/test/profanity.test.js for the server-side coverage.
*/

import 'package:flutter_test/flutter_test.dart';
import 'package:radio_apollo/models/event.dart';
import 'package:radio_apollo/services/program/program_service.dart';
import 'package:radio_apollo/utils/date_utils.dart';
import 'package:radio_apollo/utils/profanity/profanity_filter.dart';

void main() {
  // ════════════════════════════════════════════════════════════════════════
  // AppDateUtils.shiftList
  // ════════════════════════════════════════════════════════════════════════

  group('AppDateUtils.shiftList', () {
    test('shift of 0 returns the list unchanged', () {
      expect(
        AppDateUtils.shiftList(['a', 'b', 'c', 'd'], 0),
        ['a', 'b', 'c', 'd'],
      );
    });

    test('positive shift rotates left', () {
      expect(
        AppDateUtils.shiftList(['a', 'b', 'c', 'd'], 1),
        ['b', 'c', 'd', 'a'],
      );
      expect(
        AppDateUtils.shiftList(['a', 'b', 'c', 'd'], 2),
        ['c', 'd', 'a', 'b'],
      );
    });

    test('negative shift rotates right', () {
      expect(
        AppDateUtils.shiftList(['a', 'b', 'c', 'd'], -1),
        ['d', 'a', 'b', 'c'],
      );
      expect(
        AppDateUtils.shiftList(['a', 'b', 'c', 'd'], -2),
        ['c', 'd', 'a', 'b'],
      );
    });

    test('shift equal to list length is identity', () {
      expect(
        AppDateUtils.shiftList(['a', 'b', 'c'], 3),
        ['a', 'b', 'c'],
      );
    });

    test('shift larger than list length wraps around', () {
      expect(
        AppDateUtils.shiftList(['a', 'b', 'c'], 7),
        ['b', 'c', 'a'],
      );
    });

    test('does not mutate the input list', () {
      final input = ['a', 'b', 'c'];
      AppDateUtils.shiftList(input, 1);
      expect(input, ['a', 'b', 'c']);
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // AppDateUtils.formatTime
  // ════════════════════════════════════════════════════════════════════════

  group('AppDateUtils.formatTime', () {
    test('pads single-digit hours and minutes with leading zero', () {
      expect(AppDateUtils.formatTime(DateTime(2026, 5, 14, 9, 5)), '09:05');
    });

    test('handles midnight', () {
      expect(AppDateUtils.formatTime(DateTime(2026, 5, 14, 0, 0)), '00:00');
    });

    test('handles end of day', () {
      expect(AppDateUtils.formatTime(DateTime(2026, 5, 14, 23, 59)), '23:59');
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // AppDateUtils.formatScheduleTime
  // ════════════════════════════════════════════════════════════════════════

  group('AppDateUtils.formatScheduleTime', () {
    test('converts 24:00 to 00:00', () {
      expect(AppDateUtils.formatScheduleTime('24:00'), '00:00');
    });

    test('leaves other times unchanged', () {
      expect(AppDateUtils.formatScheduleTime('00:00'), '00:00');
      expect(AppDateUtils.formatScheduleTime('14:30'), '14:30');
      expect(AppDateUtils.formatScheduleTime('23:59'), '23:59');
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // AppDateUtils.formatTimeRange
  // ════════════════════════════════════════════════════════════════════════

  group('AppDateUtils.formatTimeRange', () {
    test('formats normal ranges', () {
      expect(AppDateUtils.formatTimeRange('08:00', '10:00'), '08:00 - 10:00');
    });

    test('converts 24:00 in either end to 00:00', () {
      expect(AppDateUtils.formatTimeRange('22:00', '24:00'), '22:00 - 00:00');
      expect(AppDateUtils.formatTimeRange('24:00', '06:00'), '00:00 - 06:00');
    });

    test('returns placeholder when either part is empty', () {
      expect(AppDateUtils.formatTimeRange('', '10:00'), '--:-- - --:--');
      expect(AppDateUtils.formatTimeRange('08:00', ''), '--:-- - --:--');
      expect(AppDateUtils.formatTimeRange('', ''), '--:-- - --:--');
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // AppDateUtils.parseTimeToMinutes
  // ════════════════════════════════════════════════════════════════════════

  group('AppDateUtils.parseTimeToMinutes', () {
    test('parses valid HH:mm strings', () {
      expect(AppDateUtils.parseTimeToMinutes('00:00'), 0);
      expect(AppDateUtils.parseTimeToMinutes('00:01'), 1);
      expect(AppDateUtils.parseTimeToMinutes('01:00'), 60);
      expect(AppDateUtils.parseTimeToMinutes('08:30'), 510);
      expect(AppDateUtils.parseTimeToMinutes('23:59'), 1439);
    });

    test('returns null for empty input', () {
      expect(AppDateUtils.parseTimeToMinutes(''), isNull);
    });

    test('returns null for malformed input', () {
      expect(AppDateUtils.parseTimeToMinutes('not a time'), isNull);
      expect(AppDateUtils.parseTimeToMinutes('12'), isNull);
      expect(AppDateUtils.parseTimeToMinutes('12:'), isNull);
      expect(AppDateUtils.parseTimeToMinutes('12:ab'), isNull);
      expect(AppDateUtils.parseTimeToMinutes('ab:30'), isNull);
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // AppDateUtils.isCurrentTimeInRange
  // ════════════════════════════════════════════════════════════════════════

  group('AppDateUtils.isCurrentTimeInRange', () {
    test('returns false when either bound is unparseable', () {
      expect(AppDateUtils.isCurrentTimeInRange('', '10:00'), isFalse);
      expect(AppDateUtils.isCurrentTimeInRange('08:00', ''), isFalse);
      expect(AppDateUtils.isCurrentTimeInRange('garbage', 'more'), isFalse);
    });

    test('a 00:00 - 24:00 wrap-around range covers any current time', () {
      expect(AppDateUtils.isCurrentTimeInRange('00:00', '24:00'), isTrue);
    });

    test('a zero-length range wraps and covers everything', () {
      expect(AppDateUtils.isCurrentTimeInRange('12:00', '12:00'), isTrue);
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // AppDateUtils.parseDutchDate
  // ════════════════════════════════════════════════════════════════════════

  group('AppDateUtils.parseDutchDate', () {
    test('parses standard single-day Dutch dates', () {
      expect(
        AppDateUtils.parseDutchDate('3 mei 2026'),
        DateTime(2026, 5, 3),
      );
      expect(
        AppDateUtils.parseDutchDate('15 januari 2025'),
        DateTime(2025, 1, 15),
      );
      expect(
        AppDateUtils.parseDutchDate('31 december 2026'),
        DateTime(2026, 12, 31),
      );
    });

    test('is case-insensitive on the month name', () {
      expect(
        AppDateUtils.parseDutchDate('3 MEI 2026'),
        DateTime(2026, 5, 3),
      );
      expect(
        AppDateUtils.parseDutchDate('3 Mei 2026'),
        DateTime(2026, 5, 3),
      );
    });

    test('parses multi-day "30/31 mei 2026" by taking the first day', () {
      expect(
        AppDateUtils.parseDutchDate('30/31 mei 2026'),
        DateTime(2026, 5, 30),
      );
    });

    test('parses multi-day "30-31 mei 2026" with hyphen too', () {
      expect(
        AppDateUtils.parseDutchDate('30-31 mei 2026'),
        DateTime(2026, 5, 30),
      );
    });

    test('tolerates extra whitespace', () {
      expect(
        AppDateUtils.parseDutchDate('  3   mei   2026  '),
        DateTime(2026, 5, 3),
      );
    });

    test('returns null on malformed input', () {
      expect(AppDateUtils.parseDutchDate(''), isNull);
      expect(AppDateUtils.parseDutchDate('not a date'), isNull);
      expect(AppDateUtils.parseDutchDate('3 mei'), isNull);
      expect(AppDateUtils.parseDutchDate('mei 2026'), isNull);
      expect(AppDateUtils.parseDutchDate('3 may 2026'), isNull);
      expect(AppDateUtils.parseDutchDate('xx mei 2026'), isNull);
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // ProgramService.weekdays / getWeekdayName
  // ════════════════════════════════════════════════════════════════════════

  group('ProgramService weekday helpers', () {
    test('weekdays is the seven Dutch weekday names in Monday-first order', () {
      expect(ProgramService.weekdays, [
        'Maandag',
        'Dinsdag',
        'Woensdag',
        'Donderdag',
        'Vrijdag',
        'Zaterdag',
        'Zondag',
      ]);
    });

    test('getWeekdayName maps ISO weekdays 1..7 to Maandag..Zondag', () {
      expect(ProgramService.getWeekdayName(1), 'Maandag');
      expect(ProgramService.getWeekdayName(2), 'Dinsdag');
      expect(ProgramService.getWeekdayName(3), 'Woensdag');
      expect(ProgramService.getWeekdayName(4), 'Donderdag');
      expect(ProgramService.getWeekdayName(5), 'Vrijdag');
      expect(ProgramService.getWeekdayName(6), 'Zaterdag');
      expect(ProgramService.getWeekdayName(7), 'Zondag');
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // Day-shift invariant (bug #1 regression test)
  // ════════════════════════════════════════════════════════════════════════

  group('Day-shift invariant', () {
    List<String> shiftedDaysFor(int todayWeekday, int selectedIndex) {
      final shift = todayWeekday - (selectedIndex + 1);
      return AppDateUtils.shiftList(
        List.from(ProgramService.weekdays),
        shift,
      );
    }

    test('today lands at selectedIndex for every weekday × every index', () {
      for (int todayWeekday = 1; todayWeekday <= 7; todayWeekday++) {
        final todayName = ProgramService.getWeekdayName(todayWeekday);

        for (int selectedIndex = 0; selectedIndex < 7; selectedIndex++) {
          final days = shiftedDaysFor(todayWeekday, selectedIndex);

          expect(days.length, 7, reason: 'list must always have 7 entries');
          expect(
            days[selectedIndex],
            todayName,
            reason:
                'today=$todayName (weekday=$todayWeekday), '
                'selectedIndex=$selectedIndex: '
                'expected $todayName at position $selectedIndex but got '
                '${days[selectedIndex]} (full list: $days)',
          );
          expect(
            days.toSet(),
            ProgramService.weekdays.toSet(),
            reason: 'shifted list must contain every weekday exactly once',
          );
        }
      }
    });

    test('default selectedIndex=3 puts today in the center slot', () {
      for (int todayWeekday = 1; todayWeekday <= 7; todayWeekday++) {
        final todayName = ProgramService.getWeekdayName(todayWeekday);
        final days = shiftedDaysFor(todayWeekday, 3);
        expect(days[3], todayName);
      }
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // Event model
  // ════════════════════════════════════════════════════════════════════════

  group('Event.hasImage', () {
    test('returns false when imageUrl is null', () {
      const event = Event(
        title: 't',
        date: '3 mei 2026',
        location: 'l',
        what: 'w',
      );
      expect(event.hasImage, isFalse);
    });

    test('returns false when imageUrl is empty or whitespace', () {
      const empty = Event(
        title: 't',
        date: '3 mei 2026',
        location: 'l',
        what: 'w',
        imageUrl: '',
      );
      const whitespace = Event(
        title: 't',
        date: '3 mei 2026',
        location: 'l',
        what: 'w',
        imageUrl: '   ',
      );
      expect(empty.hasImage, isFalse);
      expect(whitespace.hasImage, isFalse);
    });

    test('returns true when imageUrl is a non-empty string', () {
      const event = Event(
        title: 't',
        date: '3 mei 2026',
        location: 'l',
        what: 'w',
        imageUrl: 'https://example.com/img.png',
      );
      expect(event.hasImage, isTrue);
    });
  });

  group('Event.parsedDate', () {
    test('returns the parsed DateTime for a valid Dutch date', () {
      const event = Event(
        title: 't',
        date: '15 juni 2026',
        location: 'l',
        what: 'w',
      );
      expect(event.parsedDate, DateTime(2026, 6, 15));
    });

    test('returns null for a malformed date', () {
      const event = Event(
        title: 't',
        date: 'tomorrow',
        location: 'l',
        what: 'w',
      );
      expect(event.parsedDate, isNull);
    });
  });

  group('Event date-window getters', () {
    // Build an event date relative to today so the assertions hold
    // regardless of when the test runs.
    Event eventInDays(int days) {
      final today = DateTime.now();
      final target = DateTime(today.year, today.month, today.day)
          .add(Duration(days: days));
      const monthNames = [
        'januari',
        'februari',
        'maart',
        'april',
        'mei',
        'juni',
        'juli',
        'augustus',
        'september',
        'oktober',
        'november',
        'december',
      ];
      return Event(
        title: 't',
        date: '${target.day} ${monthNames[target.month - 1]} ${target.year}',
        location: 'l',
        what: 'w',
      );
    }

    test('daysUntil returns 0 for today', () {
      expect(eventInDays(0).daysUntil, 0);
    });

    test('daysUntil returns positive integers for future events', () {
      expect(eventInDays(1).daysUntil, 1);
      expect(eventInDays(7).daysUntil, 7);
      expect(eventInDays(30).daysUntil, 30);
    });

    test('daysUntil returns negative for past events', () {
      expect(eventInDays(-1).daysUntil, -1);
      expect(eventInDays(-30).daysUntil, -30);
    });

    test('daysUntil returns null for unparseable dates', () {
      const event = Event(
        title: 't',
        date: 'eens een keer',
        location: 'l',
        what: 'w',
      );
      expect(event.daysUntil, isNull);
    });

    test('isWithinOneWeek covers today through day 7', () {
      expect(eventInDays(0).isWithinOneWeek, isTrue);
      expect(eventInDays(7).isWithinOneWeek, isTrue);
      expect(eventInDays(8).isWithinOneWeek, isFalse);
      expect(eventInDays(-1).isWithinOneWeek, isFalse);
    });

    test('isWithinTwoWeeks covers today through day 14', () {
      expect(eventInDays(0).isWithinTwoWeeks, isTrue);
      expect(eventInDays(14).isWithinTwoWeeks, isTrue);
      expect(eventInDays(15).isWithinTwoWeeks, isFalse);
      expect(eventInDays(-1).isWithinTwoWeeks, isFalse);
    });

    test('both window getters are false for unparseable dates', () {
      const event = Event(
        title: 't',
        date: 'eens een keer',
        location: 'l',
        what: 'w',
      );
      expect(event.isWithinOneWeek, isFalse);
      expect(event.isWithinTwoWeeks, isFalse);
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // ProfanityFilter
  // ════════════════════════════════════════════════════════════════════════
  //
  // ProfanityService is uninitialised in tests, so activeSevereWords and
  // activeMildWords fall back to the hardcoded ProfanityConfig lists.
  // That's intentional and gives us a stable, well-known wordlist to
  // test against.

  group('ProfanityFilter.check', () {
    test('clean text passes through untouched', () {
      final result = ProfanityFilter.check(
        'Hallo allemaal, mooie show vandaag',
      );
      expect(result.isSevere, isFalse);
      expect(result.hasMildProfanity, isFalse);
      expect(result.cleanedText, 'Hallo allemaal, mooie show vandaag');
    });

    test('empty text is treated as clean', () {
      final result = ProfanityFilter.check('');
      expect(result.isSevere, isFalse);
      expect(result.hasMildProfanity, isFalse);
      expect(result.cleanedText, '');
    });

    test('whitespace-only text is treated as clean', () {
      final result = ProfanityFilter.check('   ');
      expect(result.isSevere, isFalse);
      expect(result.hasMildProfanity, isFalse);
    });

    test('severe slur blocks the message', () {
      // "mongool" is in the hardcoded severe list.
      final result = ProfanityFilter.check('je bent een mongool');
      expect(result.isSevere, isTrue);
    });

    test('severe slur is detected regardless of case', () {
      final result = ProfanityFilter.check('je bent een MONGOOL');
      expect(result.isSevere, isTrue);
    });

    test('mild profanity is censored, not blocked', () {
      // "shit" is in the hardcoded mild list.
      final result = ProfanityFilter.check('oh shit nog drie minuten');
      expect(result.isSevere, isFalse);
      expect(result.hasMildProfanity, isTrue);
      expect(result.cleanedText.toLowerCase().contains('shit'), isFalse);
    });

    test('clean text containing a profane substring is not flagged', () {
      // Word-boundary regression: "exploderen" must NOT match "klote",
      // "shit", or any other entry as a substring.
      final result = ProfanityFilter.check('we gaan exploderen vanavond');
      expect(result.isSevere, isFalse);
      expect(result.hasMildProfanity, isFalse);
      expect(result.cleanedText, 'we gaan exploderen vanavond');
    });
  });
}