import {
  Inject,
  Injectable,
  Logger,
  ConflictException,
  ForbiddenException,
} from '@nestjs/common';
import type { ConfigType } from '@nestjs/config';
import * as fs from 'fs/promises';
import * as path from 'path';
import { deleteFileIfExists } from '../../common/utils/file-system.util';
import { fetchPublicUrl } from '../../common/utils/public-fetch.util';
import { Prisma } from '../../generated/prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { UserStatus } from '../../generated/prisma/enums';
import type { OidcUserClaims } from './oidc.types';
import { OIDC_USER_SELECT } from './oidc.constants';
import { StorageConfig } from '../../config/configuration';
import { PUBLIC_PROFILES_PREFIX } from '../../config/storage.constants';
import { SettingsService } from '../../settings/settings.service';
import { PROFILE_IMAGE_MAX_BYTES } from '../constants/auth.constants';
import {
  PROFILE_IMAGE_EXTENSIONS,
  storedProfileImageFile,
} from '../utils/profile-image.util';

const PICTURE_DOWNLOAD_TIMEOUT_MS = 5000;

@Injectable()
export class OidcUserService {
  private readonly logger = new Logger(OidcUserService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly settingsService: SettingsService,
    @Inject(StorageConfig.KEY)
    private readonly storageConfig: ConfigType<typeof StorageConfig>,
  ) {}

  /**
   * Find or create user based on OIDC claims.
   * Links to an existing account with the same email (no OIDC link yet) only
   * when the provider says it verified that email. New accounts follow the
   * sign-up mode, like password sign-up.
   */
  async findOrCreateUser(claims: OidcUserClaims) {
    try {
      return await this.prisma.$transaction(
        async (tx) => {
          const existingBySubject = await tx.user.findUnique({
            where: { oidcSubject: claims.subject },
            select: OIDC_USER_SELECT,
          });
          if (existingBySubject) {
            const updateData: { name?: string; profileImage?: string | null } =
              {
                name: claims.name,
              };
            const profileImage = await this.resolveProfileImage(
              claims.picture,
              existingBySubject.id,
              existingBySubject.profileImage,
            );
            if (profileImage !== undefined) {
              updateData.profileImage = profileImage;
            }
            await tx.user.update({
              where: { id: existingBySubject.id },
              data: updateData,
            });
            return tx.user.findUniqueOrThrow({
              where: { id: existingBySubject.id },
              select: OIDC_USER_SELECT,
            });
          }

          const existingByEmail = await tx.user.findUnique({
            where: { email: claims.email },
          });
          if (existingByEmail) {
            if (
              existingByEmail.oidcSubject != null &&
              existingByEmail.oidcSubject !== claims.subject
            ) {
              throw new ConflictException(
                'This email is already linked to a different sign-in account.',
              );
            }
            const updateData: {
              oidcSubject?: string;
              name?: string;
              profileImage?: string | null;
            } = {
              name: claims.name,
            };
            if (!existingByEmail.oidcSubject) {
              // Otherwise anyone who can put this email on an account at the
              // provider would sign in as its owner here.
              if (!claims.emailVerified) {
                throw new ConflictException(
                  'An account with this email already exists. Your sign-in provider has not verified this email, so it can’t be linked.',
                );
              }
              updateData.oidcSubject = claims.subject;
              this.logger.log(
                `Linked OIDC subject to existing user: ${claims.email}`,
              );
            }
            const profileImage = await this.resolveProfileImage(
              claims.picture,
              existingByEmail.id,
              existingByEmail.profileImage,
            );
            if (profileImage !== undefined) {
              updateData.profileImage = profileImage;
            }
            await tx.user.update({
              where: { id: existingByEmail.id },
              data: updateData,
            });
            return tx.user.findUniqueOrThrow({
              where: { id: existingByEmail.id },
              select: OIDC_USER_SELECT,
            });
          }

          return this.createUserInTx(tx, claims);
        },
        { timeout: 10000 },
      );
    } catch (error) {
      if (
        error instanceof ConflictException ||
        error instanceof ForbiddenException
      ) {
        throw error;
      }
      // P2002 = unique constraint violation; concurrent create, re-fetch by subject
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === 'P2002'
      ) {
        const user = await this.prisma.user.findUnique({
          where: { oidcSubject: claims.subject },
          select: OIDC_USER_SELECT,
        });
        if (user) {
          return user;
        }
      }
      throw error;
    }
  }

  /**
   * Create a new user from OIDC claims (within a transaction), as the sign-up
   * mode allows. The very first account is always allowed, so an instance
   * that only signs in with OIDC can get its admin.
   */
  private async createUserInTx(
    tx: Prisma.TransactionClient,
    claims: OidcUserClaims,
  ) {
    const isFirstUser = (await tx.user.count()) === 0;
    const mode = await this.settingsService.getRegistrationMode();
    if (mode === 'disabled' && !isFirstUser) {
      throw new ForbiddenException(
        'Sign-up is closed. Ask an admin to add you.',
      );
    }
    const status =
      mode === 'review' && !isFirstUser
        ? UserStatus.pending
        : UserStatus.active;

    const adminCount = await tx.user.count({
      where: { isAdmin: true },
    });

    const newUser = await tx.user.create({
      data: {
        email: claims.email,
        name: claims.name,
        password: null,
        oidcSubject: claims.subject,
        isAdmin: adminCount === 0,
        status,
      },
      select: OIDC_USER_SELECT,
    });

    const profileImage = await this.resolveProfileImage(
      claims.picture,
      newUser.id,
      null,
    );
    if (profileImage) {
      await tx.user.update({
        where: { id: newUser.id },
        data: { profileImage },
      });
    }

    this.logger.log(`Created new OIDC user: ${claims.email}`);
    return tx.user.findUniqueOrThrow({
      where: { id: newUser.id },
      select: OIDC_USER_SELECT,
    });
  }

  /**
   * Resolve profile image from OIDC picture claim.
   * Tries to download and store; falls back to URL if download fails.
   */
  private async resolveProfileImage(
    pictureUrl: string | undefined,
    userId: string,
    oldProfileImage: string | null,
  ): Promise<string | null | undefined> {
    if (!pictureUrl) return undefined;
    const downloaded = await this.downloadPicture(
      pictureUrl,
      userId,
      oldProfileImage,
    );
    if (downloaded) return downloaded;
    try {
      // Store the parsed form: the raw claim could carry "../" segments.
      const url = new URL(pictureUrl);
      return url.protocol === 'https:' ? url.href : undefined;
    } catch {
      return undefined;
    }
  }

  private async downloadPicture(
    pictureUrl: string,
    userId: string,
    oldProfileImagePath: string | null,
  ): Promise<string | null> {
    try {
      // The claim may come from the user (many providers let them set it),
      // so only public addresses, a capped size and image types.
      const { contentType, body } = await fetchPublicUrl(pictureUrl, {
        maxBytes: PROFILE_IMAGE_MAX_BYTES,
        timeoutMs: PICTURE_DOWNLOAD_TIMEOUT_MS,
      });
      const ext = contentType && PROFILE_IMAGE_EXTENSIONS[contentType];
      if (!ext) {
        throw new Error(`Not an image: ${contentType ?? 'no content type'}`);
      }
      const filename = `${userId}-oidc-${Date.now()}${ext}`;
      const profilesDir = this.storageConfig.profilesDir;
      const filePath = path.join(profilesDir, filename);
      const imagePath = `${PUBLIC_PROFILES_PREFIX}/${filename}`;

      await fs.mkdir(profilesDir, { recursive: true });
      await fs.writeFile(filePath, body);

      const oldFullPath = storedProfileImageFile(
        profilesDir,
        oldProfileImagePath,
      );
      if (oldFullPath && oldProfileImagePath?.includes('-oidc-')) {
        await deleteFileIfExists(oldFullPath, this.logger);
      }

      this.logger.log(`Downloaded OIDC avatar for user ${userId}`);
      return imagePath;
    } catch (error) {
      this.logger.warn(
        `Failed to download OIDC picture: ${error instanceof Error ? error.message : String(error)}`,
      );
      return null;
    }
  }
}
