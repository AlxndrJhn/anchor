import { beforeEach, describe, expect, it, vi } from 'vitest';
import { ConflictException, ForbiddenException, Logger } from '@nestjs/common';
import { OidcUserService } from './oidc-user.service';
import { PrismaService } from '../../prisma/prisma.service';
import {
  RegistrationMode,
  SettingsService,
} from '../../settings/settings.service';
import { UserStatus } from '../../generated/prisma/enums';
import type { OidcUserClaims } from './oidc.types';

/**
 * OidcUserService against an in-memory user table: linking by email and
 * creating accounts under each sign-up mode.
 */
describe('OidcUserService', () => {
  interface UserRecord {
    id: string;
    email: string;
    name: string;
    oidcSubject: string | null;
    profileImage: string | null;
    isAdmin: boolean;
    status: UserStatus;
  }

  let users: UserRecord[];
  let registrationMode: RegistrationMode;
  let service: OidcUserService;

  const find = (where: Partial<UserRecord>) =>
    users.find((u) =>
      Object.entries(where).every(
        ([key, value]) => u[key as keyof UserRecord] === value,
      ),
    ) ?? null;

  const tx = {
    user: {
      findUnique: vi.fn(({ where }: { where: Partial<UserRecord> }) =>
        Promise.resolve(find(where)),
      ),
      findUniqueOrThrow: vi.fn(({ where }: { where: Partial<UserRecord> }) =>
        Promise.resolve(find(where)),
      ),
      update: vi.fn(
        ({
          where,
          data,
        }: {
          where: Partial<UserRecord>;
          data: Partial<UserRecord>;
        }) => Promise.resolve(Object.assign(find(where)!, data)),
      ),
      count: vi.fn(({ where }: { where?: Partial<UserRecord> } = {}) =>
        Promise.resolve(
          users.filter((u) =>
            Object.entries(where ?? {}).every(
              ([key, value]) => u[key as keyof UserRecord] === value,
            ),
          ).length,
        ),
      ),
      create: vi.fn(({ data }: { data: Omit<UserRecord, 'id'> }) => {
        const user = { ...data, id: `user-${users.length + 1}` };
        users.push(user);
        return Promise.resolve(user);
      }),
    },
  };

  const addUser = (overrides: Partial<UserRecord> & { id: string }) => {
    users.push({
      email: `${overrides.id}@example.com`,
      name: 'Someone',
      oidcSubject: null,
      profileImage: null,
      isAdmin: false,
      status: UserStatus.active,
      ...overrides,
    });
  };

  const claims = (overrides: Partial<OidcUserClaims> = {}): OidcUserClaims => ({
    email: 'pat@example.com',
    name: 'Pat',
    subject: 'sub-pat',
    emailVerified: true,
    ...overrides,
  });

  beforeEach(() => {
    vi.clearAllMocks();
    vi.spyOn(Logger.prototype, 'log').mockImplementation(() => {});
    users = [];
    registrationMode = 'enabled';
    const prisma = {
      $transaction: (fn: (t: typeof tx) => Promise<unknown>) => fn(tx),
    };
    const settings = {
      getRegistrationMode: () => Promise.resolve(registrationMode),
    };
    service = new OidcUserService(
      prisma as unknown as PrismaService,
      settings as unknown as SettingsService,
      { profilesDir: '/data/uploads/profiles', root: '/data' } as never,
    );
  });

  describe('linking to an account with the same email', () => {
    beforeEach(() => addUser({ id: 'admin', email: 'pat@example.com' }));

    it('links when the provider verified the email', async () => {
      const user = await service.findOrCreateUser(claims());
      expect(user?.id).toBe('admin');
      expect(find({ id: 'admin' })?.oidcSubject).toBe('sub-pat');
    });

    it('turns down an email the provider has not verified', async () => {
      await expect(
        service.findOrCreateUser(claims({ emailVerified: false })),
      ).rejects.toThrow(ConflictException);
      expect(find({ id: 'admin' })?.oidcSubject).toBeNull();
    });

    it('still signs in an account linked before, verified or not', async () => {
      find({ id: 'admin' })!.oidcSubject = 'sub-pat';
      const user = await service.findOrCreateUser(
        claims({ emailVerified: false }),
      );
      expect(user?.id).toBe('admin');
    });
  });

  describe('creating an account', () => {
    beforeEach(() => addUser({ id: 'admin', isAdmin: true }));

    it('creates an active account when sign-up is open', async () => {
      const user = await service.findOrCreateUser(claims());
      expect(user?.status).toBe(UserStatus.active);
      expect(user?.isAdmin).toBe(false);
    });

    it('makes the account wait for approval in review mode', async () => {
      registrationMode = 'review';
      const user = await service.findOrCreateUser(claims());
      expect(user?.status).toBe(UserStatus.pending);
    });

    it('turns it down when sign-up is closed', async () => {
      registrationMode = 'disabled';
      await expect(service.findOrCreateUser(claims())).rejects.toThrow(
        ForbiddenException,
      );
      expect(users).toHaveLength(1);
    });

    it('lets the very first account in as admin even when closed', async () => {
      users = [];
      registrationMode = 'disabled';
      const user = await service.findOrCreateUser(claims());
      expect(user?.status).toBe(UserStatus.active);
      expect(user?.isAdmin).toBe(true);
    });
  });
});
