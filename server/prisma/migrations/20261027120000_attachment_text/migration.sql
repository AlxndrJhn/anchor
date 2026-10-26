-- Text read from pictures, for search.
ALTER TABLE "NoteAttachment" ADD COLUMN "text" TEXT;
ALTER TABLE "NoteAttachment" ADD COLUMN "textReadAt" TIMESTAMP(3);

CREATE INDEX "NoteAttachment_type_textReadAt_idx" ON "NoteAttachment"("type", "textReadAt");
