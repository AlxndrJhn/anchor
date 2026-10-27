-- CreateEnum
CREATE TYPE "NoteLockKind" AS ENUM ('tap', 'pin', 'pattern', 'biometric');

-- AlterTable
ALTER TABLE "User" ADD COLUMN     "lockPattern" TEXT,
ADD COLUMN     "lockPin" TEXT;

-- CreateTable
CREATE TABLE "NoteLock" (
    "userId" TEXT NOT NULL,
    "noteId" TEXT NOT NULL,
    "kind" "NoteLockKind" NOT NULL,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "NoteLock_pkey" PRIMARY KEY ("userId","noteId")
);

-- CreateIndex
CREATE INDEX "NoteLock_noteId_idx" ON "NoteLock"("noteId");

-- AddForeignKey
ALTER TABLE "NoteLock" ADD CONSTRAINT "NoteLock_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "NoteLock" ADD CONSTRAINT "NoteLock_noteId_fkey" FOREIGN KEY ("noteId") REFERENCES "Note"("id") ON DELETE CASCADE ON UPDATE CASCADE;
