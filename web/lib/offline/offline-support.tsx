"use client";

import { useQueryClient } from "@tanstack/react-query";
import { useEffect } from "react";
import { useAuthStore } from "@/features/auth/store";
import { restoreOutbox } from "@/features/notes/save-queues";
import { persistQueries } from "./query-cache";

/**
 * Lets the app work offline once signed in: notes and tags kept on the
 * device, edits made offline sent later, and a service worker that serves
 * the app itself without a connection.
 */
export function OfflineSupport() {
  const queryClient = useQueryClient();
  const userId = useAuthStore((s) => s.user?.id);

  useEffect(() => {
    if (!userId) return;
    let stop: (() => void) | undefined;
    let cancelled = false;
    void persistQueries(queryClient, userId).then((cleanup) => {
      if (cancelled) {
        cleanup();
        return;
      }
      stop = cleanup;
      restoreOutbox(queryClient, userId);
    });
    return () => {
      cancelled = true;
      stop?.();
    };
  }, [queryClient, userId]);

  useEffect(() => {
    // Development serves changing files; only a build is cached.
    if (process.env.NODE_ENV !== "production") return;
    if (!("serviceWorker" in navigator)) return;
    void navigator.serviceWorker.register("/sw.js").catch(() => {});
  }, []);

  return null;
}
