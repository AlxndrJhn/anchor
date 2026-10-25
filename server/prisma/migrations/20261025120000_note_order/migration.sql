-- CreateTable
CREATE TABLE "NoteOrder" (
    "userId" TEXT NOT NULL,
    "noteId" TEXT NOT NULL,
    "position" DOUBLE PRECISION NOT NULL,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "NoteOrder_pkey" PRIMARY KEY ("userId","noteId")
);

-- CreateIndex
CREATE INDEX "NoteOrder_noteId_idx" ON "NoteOrder"("noteId");

-- AddForeignKey
ALTER TABLE "NoteOrder" ADD CONSTRAINT "NoteOrder_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "NoteOrder" ADD CONSTRAINT "NoteOrder_noteId_fkey" FOREIGN KEY ("noteId") REFERENCES "Note"("id") ON DELETE CASCADE ON UPDATE CASCADE;
