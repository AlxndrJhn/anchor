import { describe, expect, it } from 'vitest';
import { HealthController } from './health.controller';
import {
  ANCHOR_PROTOCOL,
  SUPPORTED_PROTOCOLS,
} from '../common/protocol/protocol.constants';

describe('HealthController', () => {
  it('reports the app identity, version and servable protocols', () => {
    const body = new HealthController().check();

    expect(body).toMatchObject({ status: 'ok', app: 'anchor' });
    expect(body.version).toEqual(expect.any(String));
    expect(Date.parse(body.timestamp)).not.toBeNaN();
  });

  it('advertises the protocols clients are gated on', () => {
    expect(new HealthController().check().protocols).toEqual(
      SUPPORTED_PROTOCOLS,
    );
    expect(SUPPORTED_PROTOCOLS).toContain(ANCHOR_PROTOCOL);
  });

  it('names the image it runs from, when the image says', () => {
    const before = process.env.ANCHOR_IMAGE;
    try {
      delete process.env.ANCHOR_IMAGE;
      expect(new HealthController().check().image).toBeUndefined();
      process.env.ANCHOR_IMAGE = 'ghcr.io/o/anchor:fork-preview';
      expect(new HealthController().check().image).toBe(
        'ghcr.io/o/anchor:fork-preview',
      );
    } finally {
      if (before === undefined) delete process.env.ANCHOR_IMAGE;
      else process.env.ANCHOR_IMAGE = before;
    }
  });
});
