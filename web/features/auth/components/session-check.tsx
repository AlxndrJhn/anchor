"use client";

import { type ReactNode, useEffect } from "react";
import { ServerDownScreen } from "@/components/layout/server-down-screen";
import { SplashScreen } from "@/components/layout/splash-screen";
import { useAuth } from "../hooks/use-auth";

export function SessionCheck({
  children,
  isWaiting = false,
}: {
  children: ReactNode;
  isWaiting?: boolean;
}) {
  const { user, isInitialized, unreachable, initialize } = useAuth();

  useEffect(() => {
    initialize();
  }, [initialize]);

  // With a session kept on this device the app starts offline instead.
  if (unreachable && !isInitialized && !user)
    return <ServerDownScreen onRetry={initialize} />;

  if (!isInitialized || isWaiting) {
    return <SplashScreen checking />;
  }

  return <>{children}</>;
}
