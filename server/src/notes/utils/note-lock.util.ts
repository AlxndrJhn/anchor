import { pbkdf2Sync, randomBytes, timingSafeEqual } from 'node:crypto';
import type { Prisma } from 'src/generated/prisma/client';
import { NoteLockKind } from 'src/generated/prisma/enums';

export const NOTE_LOCK_KINDS = Object.values(NoteLockKind);

// undefined leaves the person's lock on the note alone; a kind locks it with
// that; null unlocks it. Returns whether anything changed.
export async function setNoteLock(
  tx: Prisma.TransactionClient,
  userId: string,
  noteId: string,
  kind: NoteLockKind | null | undefined,
): Promise<boolean> {
  if (kind === undefined) return false;
  if (kind === null) {
    const { count } = await tx.noteLock.deleteMany({
      where: { userId, noteId },
    });
    return count > 0;
  }
  const existing = await tx.noteLock.findUnique({
    where: { userId_noteId: { userId, noteId } },
    select: { kind: true },
  });
  if (existing?.kind === kind) return false;
  await tx.noteLock.upsert({
    where: { userId_noteId: { userId, noteId } },
    create: { userId, noteId, kind },
    update: { kind },
  });
  return true;
}

/**
 * A lock's PIN or pattern, hashed as "pbkdf2-sha256$iterations$salt$hash"
 * (base64). The apps check it themselves, offline, with the same steps:
 * PBKDF2-HMAC-SHA256 over the UTF-8 secret, 32 bytes.
 */
export const LOCK_HASH_ITERATIONS = 20000;

export function hashLockSecret(secret: string): string {
  const salt = randomBytes(16);
  const hash = pbkdf2Sync(secret, salt, LOCK_HASH_ITERATIONS, 32, 'sha256');
  return [
    'pbkdf2-sha256',
    LOCK_HASH_ITERATIONS,
    salt.toString('base64'),
    hash.toString('base64'),
  ].join('$');
}

export function lockSecretMatches(secret: string, stored: string): boolean {
  const [scheme, iterations, salt, hash] = stored.split('$');
  if (scheme !== 'pbkdf2-sha256' || !salt || !hash) return false;
  const expected = Buffer.from(hash, 'base64');
  const actual = pbkdf2Sync(
    secret,
    Buffer.from(salt, 'base64'),
    Number(iterations),
    expected.length,
    'sha256',
  );
  return timingSafeEqual(actual, expected);
}
