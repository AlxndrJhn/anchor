import {
  BadRequestException,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../../prisma/prisma.service';
import { LOCK_PATTERN, LOCK_PIN } from '../dto/note-lock.dto';
import { hashLockSecret, lockSecretMatches } from '../utils/note-lock.util';

type SecretKind = 'pin' | 'pattern';

const FIELD = { pin: 'lockPin', pattern: 'lockPattern' } as const;

/**
 * The one PIN and one pattern a person opens their locked notes with. Only
 * hashes are kept, and handed to the apps so they can check them offline.
 */
@Injectable()
export class NoteLocksService {
  constructor(private prisma: PrismaService) {}

  async secrets(userId: string) {
    const user = await this.prisma.user.findUniqueOrThrow({
      where: { id: userId },
      select: { lockPin: true, lockPattern: true, password: true },
    });
    return {
      pin: user.lockPin,
      pattern: user.lockPattern,
      // Without one (a single sign-on account), the web can't stand in a
      // password for a fingerprint.
      hasPassword: !!user.password,
    };
  }

  async setSecret(
    userId: string,
    kind: SecretKind,
    secret: string,
    proof: { current?: string; password?: string },
  ) {
    if (!(kind === 'pin' ? LOCK_PIN : LOCK_PATTERN).test(secret)) {
      throw new BadRequestException(
        kind === 'pin'
          ? 'A PIN is 4 to 12 digits'
          : 'A pattern joins at least 4 dots',
      );
    }
    const user = await this.prisma.user.findUniqueOrThrow({
      where: { id: userId },
      select: { lockPin: true, lockPattern: true, password: true },
    });
    const stored = user[FIELD[kind]];
    // Replacing one takes the old one, or the account password.
    if (stored) {
      const proven =
        (proof.current !== undefined &&
          lockSecretMatches(proof.current, stored)) ||
        (proof.password !== undefined &&
          !!user.password &&
          (await bcrypt.compare(proof.password, user.password)));
      if (!proven) {
        throw new ForbiddenException(
          kind === 'pin'
            ? 'Wrong PIN or password'
            : 'Wrong pattern or password',
        );
      }
    }
    const hash = hashLockSecret(secret);
    await this.prisma.user.update({
      where: { id: userId },
      data: { [FIELD[kind]]: hash },
    });
    return this.secrets(userId);
  }

  /** For the web, which checks against the server rather than itself. */
  async verify(
    userId: string,
    kind: SecretKind | 'password',
    secret: string,
  ): Promise<{ ok: boolean }> {
    const user = await this.prisma.user.findUniqueOrThrow({
      where: { id: userId },
      select: { lockPin: true, lockPattern: true, password: true },
    });
    if (kind === 'password') {
      return {
        ok: !!user.password && (await bcrypt.compare(secret, user.password)),
      };
    }
    const stored = user[FIELD[kind]];
    return { ok: !!stored && lockSecretMatches(secret, stored) };
  }
}
