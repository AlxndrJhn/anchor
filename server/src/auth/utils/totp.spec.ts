import { describe, expect, it } from 'vitest';
import { generateTotpSecret, totpCode, totpUri, verifyTotp } from './totp';

// RFC 6238's SHA-1 key, "12345678901234567890", in base32.
const RFC_SECRET = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';

describe('totp', () => {
  it('matches the RFC 6238 test vectors (last 6 digits)', () => {
    expect(totpCode(RFC_SECRET, Math.floor(59 / 30))).toBe('287082');
    expect(totpCode(RFC_SECRET, Math.floor(1111111109 / 30))).toBe('081804');
    expect(totpCode(RFC_SECRET, Math.floor(1234567890 / 30))).toBe('005924');
    expect(totpCode(RFC_SECRET, Math.floor(20000000000 / 30))).toBe('353130');
  });

  it('accepts the current code and one step of drift', () => {
    const now = 1_700_000_000_000;
    const step = Math.floor(now / 30_000);
    expect(verifyTotp(RFC_SECRET, totpCode(RFC_SECRET, step), null, now)).toBe(
      step,
    );
    expect(
      verifyTotp(RFC_SECRET, totpCode(RFC_SECRET, step - 1), null, now),
    ).toBe(step - 1);
    expect(
      verifyTotp(RFC_SECRET, totpCode(RFC_SECRET, step - 2), null, now),
    ).toBeNull();
  });

  it('refuses a code whose step was used already', () => {
    const now = 1_700_000_000_000;
    const step = Math.floor(now / 30_000);
    const code = totpCode(RFC_SECRET, step);
    expect(verifyTotp(RFC_SECRET, code, step, now)).toBeNull();
  });

  it('ignores spaces and refuses what isn’t six digits', () => {
    const now = 1_700_000_000_000;
    const code = totpCode(RFC_SECRET, Math.floor(now / 30_000));
    expect(
      verifyTotp(RFC_SECRET, `${code.slice(0, 3)} ${code.slice(3)}`, null, now),
    ).not.toBeNull();
    expect(verifyTotp(RFC_SECRET, 'abcdef', null, now)).toBeNull();
    expect(verifyTotp(RFC_SECRET, '12345', null, now)).toBeNull();
  });

  it('makes a 32-character secret and an otpauth URI for it', () => {
    const secret = generateTotpSecret();
    expect(secret).toMatch(/^[A-Z2-7]{32}$/);
    expect(totpUri(secret, 'a@b.c', 'Anchor+')).toBe(
      `otpauth://totp/Anchor%2B%3Aa%40b.c?secret=${secret}&issuer=Anchor%2B&algorithm=SHA1&digits=6&period=30`,
    );
  });
});
