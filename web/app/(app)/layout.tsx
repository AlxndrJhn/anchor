"use client";

import { type ReactNode, useEffect, useState } from "react";
import { AppShell } from "@/components/layout/app-shell";
import { useAppliedAddons } from "@/features/addons";
import { AuthGuard, SecondFactorGate, useAuthStore } from "@/features/auth";
import { LocalNotesMove } from "@/features/import-export";
import { useLockSession } from "@/features/notes/hooks/use-note-lock";
import { OfflineSupport } from "@/lib/offline/offline-support";

export default function AppLayout({ children }: { children: ReactNode }) {
  return (
    <AuthGuard>
      <SignedIn>{children}</SignedIn>
    </AuthGuard>
  );
}

function SignedIn({ children }: { children: ReactNode }) {
  const blocked = useAuthStore((s) => !!s.user?.secondFactor?.blocked);
  // Stays up after setting one up, for the recovery codes, until they go on.
  const [gated, setGated] = useState(blocked);
  useEffect(() => {
    if (blocked) setGated(true);
  }, [blocked]);
  if (gated)
    return (
      <SecondFactorGate done={!blocked} onContinue={() => setGated(false)} />
    );
  return (
    <>
      <OfflineSupport />
      <LockSession />
      <LocalNotesMove />
      <Addons />
      <AppShell>{children}</AppShell>
    </>
  );
}

function LockSession() {
  useLockSession();
  return null;
}

function Addons() {
  useAppliedAddons();
  return null;
}
