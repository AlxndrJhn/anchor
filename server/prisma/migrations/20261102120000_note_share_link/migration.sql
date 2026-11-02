-- CreateTable
CREATE TABLE "NoteShareLink" (
    "noteId" TEXT NOT NULL,
    "token" TEXT NOT NULL,
    "permission" "NoteSharePermission" NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "NoteShareLink_pkey" PRIMARY KEY ("noteId")
);

-- CreateIndex
CREATE UNIQUE INDEX "NoteShareLink_token_key" ON "NoteShareLink"("token");

-- AddForeignKey
ALTER TABLE "NoteShareLink" ADD CONSTRAINT "NoteShareLink_noteId_fkey" FOREIGN KEY ("noteId") REFERENCES "Note"("id") ON DELETE CASCADE ON UPDATE CASCADE;
