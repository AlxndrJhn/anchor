/**
 * Email addresses are one account whatever their case: new ones are stored
 * lower-case, and lookups ignore case so accounts made before still match.
 */
export function normalizeEmail(email: string): string {
  return email.trim().toLowerCase();
}

/** A Prisma filter for [email] in any case. */
export function sameEmail(email: string) {
  return { equals: email.trim(), mode: 'insensitive' as const };
}
