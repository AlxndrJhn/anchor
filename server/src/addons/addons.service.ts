import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import type { UserAddon } from '../generated/prisma/client';
import { type AddonManifest, checkAddon } from './addon-manifest';

/** How many addons one person can have. */
export const MAX_ADDONS = 50;

export interface AddonView {
  id: string;
  addonId: string;
  version: string;
  enabled: boolean;
  manifest: AddonManifest;
  files: Record<string, string>;
  createdAt: Date;
  updatedAt: Date;
}

const view = (addon: UserAddon): AddonView => ({
  id: addon.id,
  addonId: addon.addonId,
  version: addon.version,
  enabled: addon.enabled,
  manifest: addon.manifest as unknown as AddonManifest,
  files: addon.files as Record<string, string>,
  createdAt: addon.createdAt,
  updatedAt: addon.updatedAt,
});

/** Each person's addons; apps fetch them and apply them themselves. */
@Injectable()
export class AddonsService {
  constructor(private prisma: PrismaService) {}

  async findAll(userId: string): Promise<AddonView[]> {
    const addons = await this.prisma.userAddon.findMany({
      where: { userId },
      orderBy: { createdAt: 'asc' },
    });
    return addons.map(view);
  }

  /** Installs an addon, or updates the one with its id, keeping it on or off. */
  async install(
    userId: string,
    manifest: unknown,
    files: unknown,
  ): Promise<AddonView> {
    const check = checkAddon(manifest, files);
    if (!check.ok)
      throw new BadRequestException({
        message: 'This addon is not valid',
        errors: check.errors,
      });
    const { manifest: checked, files: used } = check.addon;
    const existing = await this.prisma.userAddon.findUnique({
      where: { userId_addonId: { userId, addonId: checked.id } },
    });
    if (
      !existing &&
      (await this.prisma.userAddon.count({ where: { userId } })) >= MAX_ADDONS
    )
      throw new BadRequestException(
        `You can have up to ${MAX_ADDONS} addons; remove one first`,
      );
    const data = {
      version: checked.version,
      manifest: checked as object,
      files: used,
    };
    const addon = await this.prisma.userAddon.upsert({
      where: { userId_addonId: { userId, addonId: checked.id } },
      create: { userId, addonId: checked.id, ...data },
      update: data,
    });
    return view(addon);
  }

  async setEnabled(
    userId: string,
    id: string,
    enabled: boolean,
  ): Promise<AddonView> {
    await this.findOwn(userId, id);
    return view(
      await this.prisma.userAddon.update({ where: { id }, data: { enabled } }),
    );
  }

  async remove(userId: string, id: string): Promise<void> {
    await this.findOwn(userId, id);
    await this.prisma.userAddon.delete({ where: { id } });
  }

  private async findOwn(userId: string, id: string) {
    const addon = await this.prisma.userAddon.findFirst({
      where: { id, userId },
    });
    if (!addon) throw new NotFoundException('Addon not found');
    return addon;
  }
}
