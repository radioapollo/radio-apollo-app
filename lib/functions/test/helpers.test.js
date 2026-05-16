/* Server-side helpers tests (non-JWT).

   These cover the bits of helpers.js that don't need the JWT secret:
   - getClientIp:       safe X-Forwarded-For parsing for rate-limit buckets
   - validateUserMessage: request-body length/type validation

   getClientIp is the only thing standing between an attacker and rate
   limit bypass: if it reads the wrong header value, attackers can put
   any IP they want in the leftmost X-Forwarded-For entry and never
   share a rate-limit bucket with their previous requests.

   validateUserMessage is the first line of defence against malformed
   requests. The handler short-circuits 400 before doing anything
   stateful, so anything that gets past validation is at least
   shaped correctly.

   firebase-admin is mocked because helpers.js requires it at load
   time, but neither function under test reads from Firestore.
*/

jest.mock('firebase-admin', () => ({
  firestore: () => {
    throw new Error(
      'firebase-admin not initialised — expected in unit tests',
    );
  },
}));

const { getClientIp, validateUserMessage } = require('../helpers');

// ─── getClientIp ────────────────────────────────────────────────────────────

describe('getClientIp', () => {
  // Build a request-like object the function accepts. It only reads
  // req.headers['x-forwarded-for'] and req.socket?.remoteAddress.
  function makeReq({ xff, socketIp } = {}) {
    return {
      headers: xff !== undefined ? { 'x-forwarded-for': xff } : {},
      socket: socketIp ? { remoteAddress: socketIp } : undefined,
    };
  }

  test('returns the rightmost entry of X-Forwarded-For', () => {
    // Google's load balancer appends the real client IP on the right.
    // Anything to the left is attacker-supplied.
    const req = makeReq({ xff: '1.1.1.1, 2.2.2.2, 3.3.3.3' });
    expect(getClientIp(req)).toBe('3.3.3.3');
  });

  test('handles a single-IP X-Forwarded-For', () => {
    const req = makeReq({ xff: '4.4.4.4' });
    expect(getClientIp(req)).toBe('4.4.4.4');
  });

  test('trims whitespace around entries', () => {
    const req = makeReq({ xff: '1.1.1.1,   2.2.2.2 ,  3.3.3.3  ' });
    expect(getClientIp(req)).toBe('3.3.3.3');
  });

  test('ignores empty entries in the list', () => {
    // Some proxies emit "ip,,ip" when a hop is unknown. We must not
    // pick the empty string as the client IP.
    const req = makeReq({ xff: '1.1.1.1,,3.3.3.3' });
    expect(getClientIp(req)).toBe('3.3.3.3');
  });

  test('falls back to socket remoteAddress when XFF is missing', () => {
    const req = makeReq({ socketIp: '5.5.5.5' });
    expect(getClientIp(req)).toBe('5.5.5.5');
  });

  test('falls back to socket when XFF is the empty string', () => {
    const req = makeReq({ xff: '', socketIp: '5.5.5.5' });
    expect(getClientIp(req)).toBe('5.5.5.5');
  });

  test('returns "unknown" when neither XFF nor socket is available', () => {
    const req = makeReq();
    expect(getClientIp(req)).toBe('unknown');
  });

  // ── Attack scenarios ─────────────────────────────────────────────────────
  // These are the actual attempts an attacker could make to dodge rate
  // limiting. Each one tries to convince getClientIp that the request
  // came from an IP other than the attacker's real one.

  test('ignores attacker-controlled IPs to the LEFT of the real one', () => {
    // Attacker sends `X-Forwarded-For: rate-limit-bypass-attempt`.
    // Google's load balancer appends the real attacker IP on the
    // right: "rate-limit-bypass-attempt, REAL_IP".
    const req = makeReq({
      xff: 'forged-1, forged-2, forged-3, real.attacker.ip',
    });
    expect(getClientIp(req)).toBe('real.attacker.ip');
  });

  test('ignores leading whitespace in an attacker-controlled entry', () => {
    const req = makeReq({ xff: '  forged-with-padding, real.attacker.ip' });
    expect(getClientIp(req)).toBe('real.attacker.ip');
  });

  test('refuses to fall back to socket when XFF has entries', () => {
    // Belt-and-braces: even if for some reason both XFF and socket are
    // set, we trust XFF's rightmost entry.
    const req = makeReq({ xff: '1.1.1.1, 2.2.2.2', socketIp: '9.9.9.9' });
    expect(getClientIp(req)).toBe('2.2.2.2');
  });
});

// ─── validateUserMessage ────────────────────────────────────────────────────

describe('validateUserMessage', () => {
  test('accepts a valid username and text', () => {
    const result = validateUserMessage('Frank', 'hello there');
    expect(result.ok).toBe(true);
    expect(result.trimmedUsername).toBe('Frank');
    expect(result.trimmedText).toBe('hello there');
  });

  test('trims surrounding whitespace from both fields', () => {
    const result = validateUserMessage('  Frank  ', '  hi  ');
    expect(result.ok).toBe(true);
    expect(result.trimmedUsername).toBe('Frank');
    expect(result.trimmedText).toBe('hi');
  });

  test('rejects when username is not a string', () => {
    expect(validateUserMessage(undefined, 'hi').ok).toBe(false);
    expect(validateUserMessage(null, 'hi').ok).toBe(false);
    expect(validateUserMessage(42, 'hi').ok).toBe(false);
    expect(validateUserMessage({}, 'hi').ok).toBe(false);
  });

  test('rejects when text is not a string', () => {
    expect(validateUserMessage('Frank', undefined).ok).toBe(false);
    expect(validateUserMessage('Frank', null).ok).toBe(false);
    expect(validateUserMessage('Frank', 42).ok).toBe(false);
  });

  test('rejects username shorter than 2 characters', () => {
    const result = validateUserMessage('a', 'hi');
    expect(result.ok).toBe(false);
    expect(result.error).toMatch(/Gebruikersnaam/);
  });

  test('rejects username longer than 20 characters', () => {
    const result = validateUserMessage('a'.repeat(21), 'hi');
    expect(result.ok).toBe(false);
    expect(result.error).toMatch(/Gebruikersnaam/);
  });

  test('accepts username exactly at the boundaries', () => {
    expect(validateUserMessage('ab', 'hi').ok).toBe(true); // 2 chars
    expect(validateUserMessage('a'.repeat(20), 'hi').ok).toBe(true); // 20 chars
  });

  test('rejects an empty message after trimming', () => {
    const result = validateUserMessage('Frank', '   ');
    expect(result.ok).toBe(false);
    expect(result.error).toMatch(/Bericht/);
  });

  test('rejects a message longer than 160 chars', () => {
    const result = validateUserMessage('Frank', 'a'.repeat(161));
    expect(result.ok).toBe(false);
    expect(result.error).toMatch(/Bericht/);
  });

  test('accepts a message exactly at the upper boundary', () => {
    expect(validateUserMessage('Frank', 'a'.repeat(160)).ok).toBe(true);
  });

  test('does not crash on a username that is only whitespace', () => {
    const result = validateUserMessage('   ', 'hi');
    expect(result.ok).toBe(false);
    // Empty after trim → fails the min-length check.
    expect(result.error).toMatch(/Gebruikersnaam/);
  });
});