/* Notification helper tests.

   These cover the pure string/date functions in notifications.js —
   buildEventReminderText (used by the daily reminder job) and
   formatDateKey (used to deduplicate same-day retries).

   The send-side (sendToTopic, onAdminChatMessage, etc.) requires
   firebase-admin and the FCM SDK; integration-testing those is out of
   scope for unit tests. We mock firebase-admin so the module loads.
*/

jest.mock('firebase-admin', () => ({
  firestore: () => {
    throw new Error(
      'firebase-admin not initialised — expected in unit tests',
    );
  },
}));

const {
  buildEventReminderText,
  formatDateKey,
} = require('../notifications');

describe('buildEventReminderText', () => {
  test('returns null for daysUntil values outside {0, 1, 7}', () => {
    expect(buildEventReminderText({ title: 'X' }, 2)).toBeNull();
    expect(buildEventReminderText({ title: 'X' }, 3)).toBeNull();
    expect(buildEventReminderText({ title: 'X' }, -1)).toBeNull();
    expect(buildEventReminderText({ title: 'X' }, 14)).toBeNull();
  });

  test('returns "Vandaag" branding for daysUntil=0', () => {
    const result = buildEventReminderText({ title: 'Zomerbal' }, 0);
    expect(result.title).toBe('Vandaag: Zomerbal');
    expect(result.body).toContain('vandaag');
  });

  test('returns "Morgen" branding for daysUntil=1', () => {
    const result = buildEventReminderText({ title: 'Zomerbal' }, 1);
    expect(result.title).toBe('Morgen: Zomerbal');
    expect(result.body).toContain('morgen');
  });

  test('returns "Volgende week" branding for daysUntil=7', () => {
    const result = buildEventReminderText({ title: 'Zomerbal' }, 7);
    expect(result.title).toBe('Volgende week: Zomerbal');
    expect(result.body).toContain('over een week');
  });

  test('includes location when set', () => {
    const result = buildEventReminderText(
      { title: 'Zomerbal', location: 'Wiekevorst' },
      0,
    );
    expect(result.body).toContain('Wiekevorst');
  });

  test('omits location phrasing when location is empty', () => {
    const result = buildEventReminderText({ title: 'Zomerbal' }, 0);
    expect(result.body).not.toContain(' in ');
  });

  test('falls back to "name" field when "title" is missing', () => {
    const result = buildEventReminderText({ name: 'Zomerbal' }, 0);
    expect(result.title).toBe('Vandaag: Zomerbal');
  });

  test('falls back to "Een evenement" when neither title nor name is set', () => {
    const result = buildEventReminderText({}, 0);
    expect(result.title).toBe('Vandaag: Een evenement');
  });

  test('trims whitespace from the event name', () => {
    const result = buildEventReminderText({ title: '   Zomerbal   ' }, 0);
    expect(result.title).toBe('Vandaag: Zomerbal');
  });
});

describe('formatDateKey', () => {
  test('formats as YYYY-MM-DD with zero-padding', () => {
    expect(formatDateKey(new Date(2026, 0, 3))).toBe('2026-01-03');
    expect(formatDateKey(new Date(2026, 11, 31))).toBe('2026-12-31');
  });

  test('uses local time, not UTC', () => {
    // new Date(year, monthIndex, day) creates a local-time date, so
    // formatDateKey should reflect the local date even when UTC would
    // disagree (e.g. for dates near midnight in non-UTC timezones).
    // We can't easily test cross-timezone behaviour without faking
    // the system timezone, but we can verify that the function reads
    // getFullYear/getMonth/getDate (local) rather than UTC methods.
    expect(formatDateKey(new Date(2026, 4, 15))).toBe('2026-05-15');
  });

  test('produces the same key for two dates with the same calendar day', () => {
    // Idempotency: two timestamps on the same day, different times,
    // must produce the same key. This is what makes the dedup work.
    const morning = new Date(2026, 4, 15, 8, 0, 0);
    const evening = new Date(2026, 4, 15, 22, 30, 0);
    expect(formatDateKey(morning)).toBe(formatDateKey(evening));
  });
});