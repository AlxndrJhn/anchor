import { beforeEach, describe, expect, it, vi } from 'vitest';
import { BadRequestException, NotFoundException } from '@nestjs/common';
import { AddonsService, MAX_ADDONS } from './addons.service';
import { PrismaService } from '../prisma/prisma.service';

describe('AddonsService', () => {
  const USER = 'user-1';
  const manifest = {
    id: 'dev.example.solarized',
    name: 'Solarized',
    version: '1.0.0',
    anchorApi: 1,
    contributes: { theme: { dark: { accent: '#b58900' } } },
  };
  const row = {
    id: 'a1',
    userId: USER,
    addonId: manifest.id,
    version: '1.0.0',
    manifest,
    files: {},
    enabled: true,
    createdAt: new Date(),
    updatedAt: new Date(),
  };

  let userAddon: Record<string, ReturnType<typeof vi.fn>>;
  let service: AddonsService;

  beforeEach(() => {
    userAddon = {
      findMany: vi.fn().mockResolvedValue([row]),
      findUnique: vi.fn().mockResolvedValue(null),
      findFirst: vi.fn().mockResolvedValue(null),
      count: vi.fn().mockResolvedValue(0),
      upsert: vi.fn().mockResolvedValue(row),
      update: vi.fn().mockResolvedValue({ ...row, enabled: false }),
      delete: vi.fn().mockResolvedValue(row),
    };
    service = new AddonsService({ userAddon } as unknown as PrismaService);
  });

  it('installs a valid addon under its own id', async () => {
    const addon = await service.install(USER, manifest, {});
    expect(userAddon.upsert).toHaveBeenCalledWith({
      where: { userId_addonId: { userId: USER, addonId: manifest.id } },
      create: {
        userId: USER,
        addonId: manifest.id,
        version: '1.0.0',
        manifest,
        files: {},
      },
      update: { version: '1.0.0', manifest, files: {} },
    });
    expect(addon).not.toHaveProperty('userId');
  });

  it('refuses an invalid addon, saying why', async () => {
    const install = service.install(USER, { ...manifest, version: 'x' }, {});
    await expect(install).rejects.toBeInstanceOf(BadRequestException);
    await expect(install).rejects.toMatchObject({
      response: { errors: ['version: use a version like "1.0.0"'] },
    });
    expect(userAddon.upsert).not.toHaveBeenCalled();
  });

  it('refuses a new addon past the limit, but updates one already there', async () => {
    userAddon.count.mockResolvedValue(MAX_ADDONS);
    await expect(service.install(USER, manifest, {})).rejects.toBeInstanceOf(
      BadRequestException,
    );
    userAddon.findUnique.mockResolvedValue(row);
    await expect(service.install(USER, manifest, {})).resolves.toBeDefined();
  });

  it("doesn't touch someone else's addon", async () => {
    await expect(service.setEnabled(USER, 'a1', false)).rejects.toBeInstanceOf(
      NotFoundException,
    );
    await expect(service.remove(USER, 'a1')).rejects.toBeInstanceOf(
      NotFoundException,
    );
    expect(userAddon.findFirst).toHaveBeenCalledWith({
      where: { id: 'a1', userId: USER },
    });
    expect(userAddon.delete).not.toHaveBeenCalled();
  });

  it('turns an addon off', async () => {
    userAddon.findFirst.mockResolvedValue(row);
    const addon = await service.setEnabled(USER, 'a1', false);
    expect(addon.enabled).toBe(false);
  });
});
