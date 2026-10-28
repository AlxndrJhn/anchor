import type { Prisma } from 'src/generated/prisma/client';

// undefined leaves it alone; true makes the note invisible to this person,
// false shows it again. Returns whether anything changed.
export async function setNoteInvisible(
  tx: Prisma.TransactionClient,
  userId: string,
  noteId: string,
  isInvisible: boolean | undefined,
): Promise<boolean> {
  if (isInvisible === undefined) {
    return false;
  }
  if (isInvisible) {
    const { count } = await tx.noteInvisible.createMany({
      data: [{ userId, noteId }],
      skipDuplicates: true,
    });
    return count > 0;
  }
  const { count } = await tx.noteInvisible.deleteMany({
    where: { userId, noteId },
  });
  return count > 0;
}
