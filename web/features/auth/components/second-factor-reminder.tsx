"use client";

import { ShieldCheck } from "lucide-react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { formatLongShortDate } from "@/features/preferences";
import { useAuthStore } from "../store";

/**
 * During the grace period, reminds people who sign in with a password alone
 * to add a passkey or authenticator app, and by when.
 */
export function SecondFactorReminder() {
  const status = useAuthStore((s) => s.user?.secondFactor);
  const pathname = usePathname();
  if (!status?.needed || status.blocked) return null;
  const by = formatLongShortDate(new Date(status.deadline));
  return (
    <div
      role="status"
      className="flex flex-wrap items-center gap-x-3 gap-y-1.5 border-border/55 border-b bg-muted px-4 py-2 text-meta"
    >
      <ShieldCheck aria-hidden className="size-4 flex-none" />
      <span className="min-w-0 flex-1">
        Your admin asks everyone to add a passkey or an authenticator app by{" "}
        {by}. After that, a password alone won’t sign you in.
      </span>
      {pathname !== "/settings" && (
        <Link
          href="/settings#set-security"
          className="font-semibold underline underline-offset-3"
        >
          Set one up
        </Link>
      )}
    </div>
  );
}
