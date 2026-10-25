import type { Prisma } from 'src/generated/prisma/client';

// undefined leaves the person's place for the note alone; a number sets it;
// null drops it, so the note sorts by when it was made. Returns whether
// anything changed.
export async function setNotePosition(
  tx: Prisma.TransactionClient,
  userId: string,
  noteId: string,
  position: number | null | undefined,
): Promise<boolean> {
  if (position === undefined) return false;
  if (position === null) {
    const { count } = await tx.noteOrder.deleteMany({
      where: { userId, noteId },
    });
    return count > 0;
  }
  const existing = await tx.noteOrder.findUnique({
    where: { userId_noteId: { userId, noteId } },
    select: { position: true },
  });
  if (existing?.position === position) return false;
  await tx.noteOrder.upsert({
    where: { userId_noteId: { userId, noteId } },
    create: { userId, noteId, position },
    update: { position },
  });
  return true;
}
