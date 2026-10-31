import { HttpException } from '@nestjs/common';
import { describe, expect, it } from 'vitest';
import { AttemptLimiter } from './attempt-limiter';

describe('AttemptLimiter', () => {
  it('refuses a key after too many failures until its window ends', () => {
    const limiter = new AttemptLimiter(3, 60_000);
    for (let i = 0; i < 3; i++) {
      limiter.check('a', 0);
      limiter.fail('a', 0);
    }
    expect(() => limiter.check('a', 1_000)).toThrow(HttpException);
    expect(() => limiter.check('b', 1_000)).not.toThrow();
    expect(() => limiter.check('a', 60_000)).not.toThrow();
  });

  it('starts over after a success', () => {
    const limiter = new AttemptLimiter(2, 60_000);
    limiter.fail('a', 0);
    limiter.succeed('a');
    limiter.fail('a', 0);
    expect(() => limiter.check('a', 0)).not.toThrow();
  });

  it('keeps no more keys than it is allowed', () => {
    const limiter = new AttemptLimiter(1, 60_000, 2);
    limiter.fail('a', 0);
    limiter.fail('b', 0);
    limiter.fail('c', 0);
    expect(() => limiter.check('a', 0)).not.toThrow();
    expect(() => limiter.check('c', 0)).toThrow(HttpException);
  });
});
