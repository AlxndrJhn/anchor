import { beforeEach, describe, expect, it, vi } from 'vitest';
import { Logger } from '@nestjs/common';
import { ClientError, discovery } from 'openid-client';
import { OidcClientService } from './oidc-client.service';
import { OidcConfigService } from './oidc-config.service';

vi.mock('openid-client', async (importOriginal) => ({
  ...(await importOriginal<typeof import('openid-client')>()),
  discovery: vi.fn(),
}));

/** The admin's "Test" button: what it says about each issuer URL. */
describe('OidcClientService.testIssuer', () => {
  const discover = vi.mocked(discovery);
  let service: OidcClientService;

  beforeEach(() => {
    vi.clearAllMocks();
    vi.spyOn(Logger.prototype, 'warn').mockImplementation(() => {});
    service = new OidcClientService({
      getOidcCallbackUrl: () => 'https://notes.example.com/cb',
    } as unknown as OidcConfigService);
  });

  it('reports the issuer and PKCE support', async () => {
    discover.mockResolvedValue({
      serverMetadata: () => ({
        issuer: 'https://id.example.com',
        code_challenge_methods_supported: ['S256'],
      }),
    } as never);
    expect(await service.testIssuer('https://id.example.com')).toEqual({
      ok: true,
      issuer: 'https://id.example.com',
      supportsPkce: true,
    });
  });

  it('offers the issuer the provider publishes when it differs', async () => {
    discover.mockRejectedValue(
      new ClientError('mismatch', {
        cause: {
          attribute: 'issuer',
          body: { issuer: 'https://id.example.com/' },
        },
      }),
    );
    expect(await service.testIssuer('https://id.example.com/x')).toMatchObject({
      ok: false,
      issuer: 'https://id.example.com/',
    });
  });

  it('explains localhost inside Docker when nothing answers', async () => {
    discover.mockRejectedValue(
      new TypeError('fetch failed', {
        cause: Object.assign(new AggregateError([]), { code: 'ECONNREFUSED' }),
      }),
    );
    const result = await service.testIssuer('http://localhost:1411');
    expect(result.ok).toBe(false);
    expect(!result.ok && result.message).toMatch(/Docker/);
  });

  it('turns down something that is not a URL without fetching', async () => {
    expect((await service.testIssuer('id.example.com')).ok).toBe(false);
    expect(discover).not.toHaveBeenCalled();
  });
});
