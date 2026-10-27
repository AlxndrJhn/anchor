"use client";

import type { ReactNode } from "react";
import { AppShell } from "@/components/layout/app-shell";
import { AuthGuard } from "@/features/auth";
import { useLockSession } from "@/features/notes/hooks/use-note-lock";
import { OfflineSupport } from "@/lib/offline/offline-support";

export default function AppLayout({ children }: { children: ReactNode }) {
  return (
    <AuthGuard>
      <OfflineSupport />
      <LockSession />
      <AppShell>{children}</AppShell>
    </AuthGuard>
  );
}

function LockSession() {
  useLockSession();
  return null;
}
