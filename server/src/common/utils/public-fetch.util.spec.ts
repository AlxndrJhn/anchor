import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import * as http from 'http';
import type { AddressInfo } from 'net';
import { fetchPublicUrl, isPublicAddress } from './public-fetch.util';

describe('isPublicAddress', () => {
  it.each([['93.184.216.34'], ['8.8.8.8'], ['2606:4700:4700::1111']])(
    'lets %s through',
    (address) => {
      expect(isPublicAddress(address)).toBe(true);
    },
  );

  it.each([
    ['127.0.0.1'],
    ['10.1.2.3'],
    ['172.16.0.1'],
    ['192.168.1.1'],
    ['169.254.169.254'],
    ['100.64.0.1'],
    ['0.0.0.0'],
    ['::1'],
    ['::'],
    ['::ffff:127.0.0.1'],
    ['fd00::1'],
    ['fe80::1'],
    ['not an address'],
  ])('blocks %s', (address) => {
    expect(isPublicAddress(address)).toBe(false);
  });
});

describe('fetchPublicUrl', () => {
  // A server on this machine stands in for anything internal.
  let server: http.Server;
  let port: number;
  const options = { maxBytes: 1024, timeoutMs: 2000 };

  beforeAll(async () => {
    server = http.createServer((_req, res) => res.end('internal'));
    await new Promise<void>((resolve) => server.listen(0, resolve));
    port = (server.address() as AddressInfo).port;
  });

  afterAll(() => new Promise<void>((resolve) => server.close(() => resolve())));

  it('refuses a literal internal address', async () => {
    await expect(
      fetchPublicUrl(`http://127.0.0.1:${port}/`, options),
    ).rejects.toThrow(/non-public/);
    await expect(
      fetchPublicUrl('http://169.254.169.254/latest/meta-data/', options),
    ).rejects.toThrow(/non-public/);
  });

  it('refuses a name that resolves to an internal address', async () => {
    await expect(
      fetchPublicUrl(`http://localhost:${port}/`, options),
    ).rejects.toThrow(/non-public/);
  });

  it('refuses other protocols', async () => {
    await expect(fetchPublicUrl('file:///etc/passwd', options)).rejects.toThrow(
      /Unsupported protocol/,
    );
  });
});
