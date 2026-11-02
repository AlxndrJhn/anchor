-- Each token signed in so far becomes a session of its own. The default
-- stays, so upstream Anchor, which doesn't know the column, can still sign
-- people in on this database.
ALTER TABLE "RefreshToken" ADD COLUMN "sessionId" TEXT NOT NULL DEFAULT gen_random_uuid()::text;
ALTER TABLE "RefreshToken" ADD COLUMN "signedInAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;
UPDATE "RefreshToken" SET "signedInAt" = "createdAt";
ALTER TABLE "RefreshToken" ADD COLUMN "userAgent" TEXT;

-- CreateIndex
CREATE INDEX "RefreshToken_sessionId_idx" ON "RefreshToken"("sessionId");
