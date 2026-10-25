"use client";

import type { ReactNode } from "react";
import { AppShell } from "@/components/layout/app-shell";
import { AuthGuard } from "@/features/auth";
import { OfflineSupport } from "@/lib/offline/offline-support";

export default function AppLayout({ children }: { children: ReactNode }) {
  return (
    <AuthGuard>
      <OfflineSupport />
      <AppShell>{children}</AppShell>
    </AuthGuard>
  );
}
