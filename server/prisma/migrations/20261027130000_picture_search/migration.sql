-- Finding pictures by what they show, for users who turn it on.
ALTER TABLE "User" ADD COLUMN "pictureSearch" BOOLEAN NOT NULL DEFAULT false;

-- CreateTable
CREATE TABLE "PictureEmbedding" (
    "attachmentId" TEXT NOT NULL,
    "model" TEXT NOT NULL,
    "vector" BYTEA NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "PictureEmbedding_pkey" PRIMARY KEY ("attachmentId")
);

-- AddForeignKey
ALTER TABLE "PictureEmbedding" ADD CONSTRAINT "PictureEmbedding_attachmentId_fkey" FOREIGN KEY ("attachmentId") REFERENCES "NoteAttachment"("id") ON DELETE CASCADE ON UPDATE CASCADE;
