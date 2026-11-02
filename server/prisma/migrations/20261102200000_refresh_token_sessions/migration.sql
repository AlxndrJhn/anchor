-- Each token signed in so far becomes a session of its own.
ALTER TABLE "RefreshToken" ADD COLUMN "sessionId" TEXT NOT NULL DEFAULT gen_random_uuid()::text;
ALTER TABLE "RefreshToken" ALTER COLUMN "sessionId" DROP DEFAULT;
ALTER TABLE "RefreshToken" ADD COLUMN "signedInAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;
UPDATE "RefreshToken" SET "signedInAt" = "createdAt";
ALTER TABLE "RefreshToken" ADD COLUMN "userAgent" TEXT;

-- CreateIndex
CREATE INDEX "RefreshToken_sessionId_idx" ON "RefreshToken"("sessionId");
