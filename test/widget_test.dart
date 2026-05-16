/* Unit tests for pure-logic helpers.

   See lib/functions/test/.test.js for the server-side counterpart.
   This file covers Flutter-side pure logic:
     - AppDateUtils (date/time helpers)
     - ProgramService weekday helpers and the day-shift invariant
     - Event model getters
     - ProfanityFilter
     - Message.fromFirestoreData (defensive parsing)
     - NotificationRouter (notification → tab routing)
     - AppCheckHttp (HTTP layer with mocked client and token fetcher)

   All tests run under plain `flutter test` with no Firebase or
   platform-channel setup.
*/

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:radio_apollo/models/event.dart';
import 'package:radio_apollo/models/message.dart';
import 'package:radio_apollo/services/chat/app_check_http.dart';
import 'package:radio_apollo/services/notifications/notification_router.dart';
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
      expect(AppDateUtils.shiftList(['a', 'b', 'c', 'd'], 1), [
        'b',
        'c',
        'd',
        'a',
      ]);
      expect(AppDateUtils.shiftList(['a', 'b', 'c', 'd'], 2), [
        'c',
        'd',
        'a',
        'b',
      ]);
    });

    test('negative shift rotates right', () {
      expect(AppDateUtils.shiftList(['a', 'b', 'c', 'd'], -1), [
        'd',
        'a',
        'b',
        'c',
      ]);
      expect(AppDateUtils.shiftList(['a', 'b', 'c', 'd'], -2), [
        'c',
        'd',
        'a',
        'b',
      ]);
    });

    test('shift equal to list length is identity', () {
      expect(AppDateUtils.shiftList(['a', 'b', 'c'], 3), ['a', 'b', 'c']);
    });

    test('shift larger than list length wraps around', () {
      expect(AppDateUtils.shiftList(['a', 'b', 'c'], 7), ['b', 'c', 'a']);
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
      expect(AppDateUtils.parseDutchDate('3 mei 2026'), DateTime(2026, 5, 3));
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
      expect(AppDateUtils.parseDutchDate('3 MEI 2026'), DateTime(2026, 5, 3));
      expect(AppDateUtils.parseDutchDate('3 Mei 2026'), DateTime(2026, 5, 3));
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
    Event eventInDays(int days) {
      final today = DateTime.now();
      final target = DateTime(
        today.year,
        today.month,
        today.day,
      ).add(Duration(days: days));
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
      final result = ProfanityFilter.check('je bent een mongool');
      expect(result.isSevere, isTrue);
    });

    test('severe slur is detected regardless of case', () {
      final result = ProfanityFilter.check('je bent een MONGOOL');
      expect(result.isSevere, isTrue);
    });

    test('mild profanity is censored, not blocked', () {
      final result = ProfanityFilter.check('oh shit nog drie minuten');
      expect(result.isSevere, isFalse);
      expect(result.hasMildProfanity, isTrue);
      expect(result.cleanedText.toLowerCase().contains('shit'), isFalse);
    });

    test('clean text containing a profane substring is not flagged', () {
      final result = ProfanityFilter.check('we gaan exploderen vanavond');
      expect(result.isSevere, isFalse);
      expect(result.hasMildProfanity, isFalse);
      expect(result.cleanedText, 'we gaan exploderen vanavond');
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // Message.fromFirestoreData
  // ════════════════════════════════════════════════════════════════════════
  //
  // The chat list calls this once per doc. A single malformed message
  // must not throw — it just gets shown with fallback values. That's
  // why this pinning matters: a future schema drift on one doc can't
  // crash the entire chat for everyone.

  group('Message.fromFirestoreData — happy path', () {
    test('parses a well-formed user message', () {
      final msg = Message.fromFirestoreData(
        docId: 'abc123',
        data: {
          'role': 'user',
          'text': 'hello world',
          'username': 'Frank',
          'likes': 3,
          'replyCount': 0,
          'likedBy': {'Frank': true},
        },
        time: '14:30',
        localUsername: 'Frank',
        isAdminViewer: false,
      );
      expect(msg.id, 'abc123');
      expect(msg.role, 'user');
      expect(msg.text, 'hello world');
      expect(msg.username, 'Frank');
      expect(msg.time, '14:30');
      expect(msg.likes, 3);
      expect(msg.likedByMe, isTrue);
      expect(msg.replyCount, 0);
      expect(msg.isCurrentUser, isTrue);
      expect(msg.replyTo, isNull);
    });

    test('parses an admin message and never marks it as isCurrentUser', () {
      final msg = Message.fromFirestoreData(
        docId: 'abc',
        data: {'role': 'admin', 'text': 'studio reply', 'username': 'Studio'},
        time: '14:30',
        localUsername: 'Studio',
        isAdminViewer: false,
      );
      expect(msg.role, 'admin');
      expect(msg.isCurrentUser, isFalse);
    });

    test('isCurrentUser is false when viewed by an admin', () {
      final msg = Message.fromFirestoreData(
        docId: 'abc',
        data: {'role': 'user', 'text': 'hi', 'username': 'Frank'},
        time: '14:30',
        localUsername: 'Frank',
        isAdminViewer: true,
      );
      expect(msg.isCurrentUser, isFalse);
    });

    test('parses a replyTo snapshot', () {
      final msg = Message.fromFirestoreData(
        docId: 'abc',
        data: {
          'role': 'user',
          'text': 'agreed',
          'username': 'Frank',
          'replyTo': {
            'messageId': 'parent-id',
            'username': 'Alice',
            'textPreview': 'who else?',
          },
        },
        time: '14:30',
        localUsername: null,
        isAdminViewer: false,
      );
      expect(msg.replyTo, isNotNull);
      expect(msg.replyTo!.messageId, 'parent-id');
      expect(msg.replyTo!.username, 'Alice');
      expect(msg.replyTo!.textPreview, 'who else?');
    });
  });

  group('Message.fromFirestoreData — defensive parsing', () {
    test('missing text falls back to empty string', () {
      final msg = Message.fromFirestoreData(
        docId: 'abc',
        data: {'role': 'user', 'username': 'Frank'},
        time: '14:30',
        localUsername: null,
        isAdminViewer: false,
      );
      expect(msg.text, '');
    });

    test('missing role falls back to "user"', () {
      final msg = Message.fromFirestoreData(
        docId: 'abc',
        data: {'text': 'hi', 'username': 'Frank'},
        time: '14:30',
        localUsername: null,
        isAdminViewer: false,
      );
      expect(msg.role, 'user');
    });

    test('missing username falls back to "Onbekend"', () {
      final msg = Message.fromFirestoreData(
        docId: 'abc',
        data: {'role': 'user', 'text': 'hi'},
        time: '14:30',
        localUsername: null,
        isAdminViewer: false,
      );
      expect(msg.username, 'Onbekend');
    });

    test('missing likes/replyCount default to 0', () {
      final msg = Message.fromFirestoreData(
        docId: 'abc',
        data: {'role': 'user', 'text': 'hi', 'username': 'Frank'},
        time: '14:30',
        localUsername: null,
        isAdminViewer: false,
      );
      expect(msg.likes, 0);
      expect(msg.replyCount, 0);
    });

    test('likes given as a double is coerced to int', () {
      // Firestore can return numeric fields as either int or double.
      final msg = Message.fromFirestoreData(
        docId: 'abc',
        data: {'role': 'user', 'text': 'hi', 'username': 'Frank', 'likes': 5.0},
        time: '14:30',
        localUsername: null,
        isAdminViewer: false,
      );
      expect(msg.likes, 5);
    });

    test('replyTo that is not a map is ignored, not thrown', () {
      final msg = Message.fromFirestoreData(
        docId: 'abc',
        data: {
          'role': 'user',
          'text': 'hi',
          'username': 'Frank',
          'replyTo': 'this should be a map',
        },
        time: '14:30',
        localUsername: null,
        isAdminViewer: false,
      );
      expect(msg.replyTo, isNull);
    });

    test('replyTo with missing username falls back gracefully', () {
      final msg = Message.fromFirestoreData(
        docId: 'abc',
        data: {
          'role': 'user',
          'text': 'hi',
          'username': 'Frank',
          'replyTo': {'messageId': 'parent'},
        },
        time: '14:30',
        localUsername: null,
        isAdminViewer: false,
      );
      expect(msg.replyTo, isNotNull);
      expect(msg.replyTo!.username, 'Onbekend');
      expect(msg.replyTo!.textPreview, '');
    });

    test('likedBy entries other than `true` do not mark likedByMe', () {
      // Defensive: the doc might have stale entries from a schema where
      // the value was a timestamp. We only count the literal `true`.
      final msg = Message.fromFirestoreData(
        docId: 'abc',
        data: {
          'role': 'user',
          'text': 'hi',
          'username': 'Frank',
          'likedBy': {'Frank': 'sometimes'},
        },
        time: '14:30',
        localUsername: 'Frank',
        isAdminViewer: false,
      );
      expect(msg.likedByMe, isFalse);
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // NotificationRouter
  // ════════════════════════════════════════════════════════════════════════

  group('NotificationRouter', () {
    setUp(() {
      // Router is a singleton, so reset between tests.
      NotificationRouter.instance.consume();
    });

    test('starts with no requested tab', () {
      expect(NotificationRouter.instance.requestedTab.value, isNull);
    });

    test('maps studio_messages → tab 4 (chat)', () {
      NotificationRouter.instance.setRequestedTabForCategory(
        'studio_messages',
      );
      expect(NotificationRouter.instance.requestedTab.value, 4);
    });

    test('maps chat_activity → tab 4 (chat)', () {
      NotificationRouter.instance.setRequestedTabForCategory('chat_activity');
      expect(NotificationRouter.instance.requestedTab.value, 4);
    });

    test('maps events → tab 3 (evenementen)', () {
      NotificationRouter.instance.setRequestedTabForCategory('events');
      expect(NotificationRouter.instance.requestedTab.value, 3);
    });

    test('does nothing for unknown categories', () {
      // Set a known value first so we can detect "did the unknown
      // category accidentally clobber state".
      NotificationRouter.instance.setRequestedTabForCategory('events');
      expect(NotificationRouter.instance.requestedTab.value, 3);

      NotificationRouter.instance.setRequestedTabForCategory('mystery');
      expect(NotificationRouter.instance.requestedTab.value, 3);
    });

    test('does nothing for null category', () {
      NotificationRouter.instance.setRequestedTabForCategory(null);
      expect(NotificationRouter.instance.requestedTab.value, isNull);
    });

    test('consume() clears the requested tab', () {
      NotificationRouter.instance.setRequestedTabForCategory(
        'studio_messages',
      );
      expect(NotificationRouter.instance.requestedTab.value, 4);
      NotificationRouter.instance.consume();
      expect(NotificationRouter.instance.requestedTab.value, isNull);
    });

    test('listeners fire when the value changes', () {
      int? lastObserved;
      void listener() {
        lastObserved = NotificationRouter.instance.requestedTab.value;
      }

      NotificationRouter.instance.requestedTab.addListener(listener);
      try {
        NotificationRouter.instance.setRequestedTabForCategory(
          'studio_messages',
        );
        expect(lastObserved, 4);

        NotificationRouter.instance.consume();
        expect(lastObserved, isNull);
      } finally {
        NotificationRouter.instance.requestedTab.removeListener(listener);
      }
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // AppCheckHttp
  // ════════════════════════════════════════════════════════════════════════

  group('AppCheckHttp.post', () {
    // Helper builders so the function-literal return type is inferred
    // correctly against AppCheckTokenFetcher (which is
    // Future<String?> Function(...)). Inline `async => 'value'` would
    // infer Future<String>, which Dart refuses to assign to a slot
    // typed Future<String?>.
    AppCheckTokenFetcher stubToken(String? value) =>
        ({required Duration timeout}) async => value;
    AppCheckTokenFetcher stubTokenThrows() =>
        ({required Duration timeout}) async {
          throw Exception('appcheck broken');
        };

    tearDown(() {
      AppCheckHttp.resetForTesting();
    });

    test('attaches X-Firebase-AppCheck header when token is available',
        () async {
      AppCheckHttp.tokenFetcher = stubToken('fake-token');

      String? capturedAuthHeader;
      AppCheckHttp.clientFactory = () => MockClient((req) async {
        capturedAuthHeader = req.headers['X-Firebase-AppCheck'];
        return http.Response('{"ok":true}', 200);
      });

      final response = await AppCheckHttp.post('userSendMessage', {'k': 'v'});
      expect(response.statusCode, 200);
      expect(capturedAuthHeader, 'fake-token');
    });

    test('omits X-Firebase-AppCheck header when token fetch returns null',
        () async {
      AppCheckHttp.tokenFetcher = stubToken(null);

      Map<String, String>? capturedHeaders;
      AppCheckHttp.clientFactory = () => MockClient((req) async {
        capturedHeaders = req.headers;
        return http.Response('{"ok":true}', 200);
      });

      await AppCheckHttp.post('userSendMessage', {});
      expect(capturedHeaders!.containsKey('X-Firebase-AppCheck'), isFalse);
    });

    test('soft-fails when token fetcher throws and requireAppCheck is false',
        () async {
      // The non-strict path swallows token-fetch errors and proceeds
      // without the header. The server decides what to do.
      AppCheckHttp.tokenFetcher = stubTokenThrows();
      AppCheckHttp.clientFactory = () => MockClient((req) async {
        return http.Response('{"ok":true}', 200);
      });

      final response = await AppCheckHttp.post('userSendMessage', {});
      expect(response.statusCode, 200);
    });

    test(
      'throws a localised error when token fetcher fails and requireAppCheck is true',
      () async {
        AppCheckHttp.tokenFetcher = stubTokenThrows();
        AppCheckHttp.clientFactory = () => MockClient((req) async {
          // We expect to NEVER reach the network in this case.
          fail('Should not have made a network call');
        });

        await expectLater(
          AppCheckHttp.post('claimUsername', {}, requireAppCheck: true),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('beveiligingstoken'),
            ),
          ),
        );
      },
    );

    test('serialises the body as JSON', () async {
      AppCheckHttp.tokenFetcher = stubToken(null);

      String? capturedBody;
      AppCheckHttp.clientFactory = () => MockClient((req) async {
        capturedBody = req.body;
        return http.Response('{"ok":true}', 200);
      });

      await AppCheckHttp.post('userSendMessage', {
        'username': 'Frank',
        'text': 'hi',
      });
      expect(capturedBody, '{"username":"Frank","text":"hi"}');
    });

    test('passes through non-2xx responses without throwing', () async {
      // The caller handles 4xx by reading response.statusCode — the
      // helper does not throw for application-level errors.
      AppCheckHttp.tokenFetcher = stubToken(null);
      AppCheckHttp.clientFactory = () => MockClient((req) async {
        return http.Response('{"error":"too fast"}', 429);
      });

      final response = await AppCheckHttp.post('userSendMessage', {});
      expect(response.statusCode, 429);
    });

    test('translates network errors to a friendly Dutch message', () async {
      AppCheckHttp.tokenFetcher = stubToken(null);
      AppCheckHttp.clientFactory = () => MockClient((req) async {
        throw http.ClientException('connection refused');
      });

      await expectLater(
        AppCheckHttp.post('userSendMessage', {}),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('netwerk'),
          ),
        ),
      );
    });
  });
}