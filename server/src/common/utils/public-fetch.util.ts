import * as dns from 'dns';
import * as http from 'http';
import * as https from 'https';
import * as net from 'net';

// Addresses a URL from outside (an OIDC picture claim, say) must never reach:
// this machine, the private network, link-local (cloud metadata lives at
// 169.254.169.254) and the other special-use ranges.
const BLOCKED = new net.BlockList();
for (const [network, prefix] of [
  ['0.0.0.0', 8],
  ['10.0.0.0', 8],
  ['100.64.0.0', 10],
  ['127.0.0.0', 8],
  ['169.254.0.0', 16],
  ['172.16.0.0', 12],
  ['192.0.0.0', 24],
  ['192.0.2.0', 24],
  ['192.88.99.0', 24],
  ['192.168.0.0', 16],
  ['198.18.0.0', 15],
  ['198.51.100.0', 24],
  ['203.0.113.0', 24],
  ['224.0.0.0', 4],
  ['240.0.0.0', 4],
] as const) {
  BLOCKED.addSubnet(network, prefix, 'ipv4');
}
for (const [network, prefix] of [
  ['::', 128],
  ['::1', 128],
  // No ::ffff:0:0/96 here: BlockList checks IPv4-mapped addresses against the
  // IPv4 rules already, and that rule would match every IPv4 address.
  ['64:ff9b::', 96],
  ['64:ff9b:1::', 48],
  ['100::', 64],
  ['2001::', 32],
  ['2001:db8::', 32],
  ['2002::', 16],
  ['fc00::', 7],
  ['fe80::', 10],
  ['ff00::', 8],
] as const) {
  BLOCKED.addSubnet(network, prefix, 'ipv6');
}

export function isPublicAddress(address: string): boolean {
  const family = net.isIP(address);
  if (family === 0) return false;
  return !BLOCKED.check(address, family === 4 ? 'ipv4' : 'ipv6');
}

class BlockedAddressError extends Error {
  constructor(host: string) {
    super(`Refusing to fetch from non-public address: ${host}`);
  }
}

// Checks the addresses a name resolves to at connect time, so a name can't
// pass a check and then resolve somewhere else for the real request.
const publicLookup: net.LookupFunction = (hostname, options, callback) => {
  dns.lookup(hostname, { ...options, all: true }, (error, addresses) => {
    if (error) return callback(error, '', 0);
    if (
      addresses.length === 0 ||
      addresses.some((a) => !isPublicAddress(a.address))
    ) {
      return callback(new BlockedAddressError(hostname), '', 0);
    }
    if (options.all) return callback(null, addresses);
    callback(null, addresses[0].address, addresses[0].family);
  });
};

export interface PublicFetchResult {
  contentType: string | undefined;
  body: Buffer;
}

export interface PublicFetchOptions {
  maxBytes: number;
  timeoutMs: number;
  maxRedirects?: number;
}

/**
 * GET a URL from outside, reaching only public addresses (redirects are
 * followed and checked the same way). The body is capped at `maxBytes` and
 * the whole request at `timeoutMs`.
 */
export async function fetchPublicUrl(
  url: string,
  { maxBytes, timeoutMs, maxRedirects = 3 }: PublicFetchOptions,
): Promise<PublicFetchResult> {
  const signal = AbortSignal.timeout(timeoutMs);
  let current = new URL(url);
  for (let redirects = 0; ; redirects++) {
    const response = await getOnce(current, maxBytes, signal);
    if (!('location' in response)) return response;
    if (redirects >= maxRedirects) throw new Error('Too many redirects');
    current = new URL(response.location, current);
  }
}

function getOnce(
  url: URL,
  maxBytes: number,
  signal: AbortSignal,
): Promise<PublicFetchResult | { location: string }> {
  return new Promise((resolve, reject) => {
    if (url.protocol !== 'https:' && url.protocol !== 'http:') {
      return reject(new Error(`Unsupported protocol: ${url.protocol}`));
    }
    // A literal IP never goes through the lookup, so check it here.
    const host = url.hostname.replace(/^\[|\]$/g, '');
    if (net.isIP(host) && !isPublicAddress(host)) {
      return reject(new BlockedAddressError(host));
    }

    const client = url.protocol === 'https:' ? https : http;
    const request = client.get(
      url,
      { lookup: publicLookup, signal },
      (response) => {
        const status = response.statusCode ?? 0;
        if (status >= 300 && status < 400 && response.headers.location) {
          response.resume();
          return resolve({ location: response.headers.location });
        }
        if (status < 200 || status >= 300) {
          response.resume();
          return reject(new Error(`Request failed with status ${status}`));
        }
        const declared = Number(response.headers['content-length']);
        if (declared > maxBytes) {
          response.destroy();
          return reject(new Error('Response too large'));
        }

        const chunks: Buffer[] = [];
        let size = 0;
        response.on('data', (chunk: Buffer) => {
          size += chunk.length;
          if (size > maxBytes) {
            response.destroy(new Error('Response too large'));
            return;
          }
          chunks.push(chunk);
        });
        response.on('error', reject);
        response.on('end', () =>
          resolve({
            contentType: response.headers['content-type']
              ?.split(';')[0]
              ?.trim()
              .toLowerCase(),
            body: Buffer.concat(chunks),
          }),
        );
      },
    );
    request.on('error', reject);
  });
}
