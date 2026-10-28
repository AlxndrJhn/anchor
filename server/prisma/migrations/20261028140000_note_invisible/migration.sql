-- CreateTable
CREATE TABLE "NoteInvisible" (
    "userId" TEXT NOT NULL,
    "noteId" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "NoteInvisible_pkey" PRIMARY KEY ("userId","noteId")
);

-- CreateIndex
CREATE INDEX "NoteInvisible_noteId_idx" ON "NoteInvisible"("noteId");

-- AddForeignKey
ALTER TABLE "NoteInvisible" ADD CONSTRAINT "NoteInvisible_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "NoteInvisible" ADD CONSTRAINT "NoteInvisible_noteId_fkey" FOREIGN KEY ("noteId") REFERENCES "Note"("id") ON DELETE CASCADE ON UPDATE CASCADE;
