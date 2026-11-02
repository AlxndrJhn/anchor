"use client";

import { useQueryClient } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { type ReactNode, useEffect } from "react";
import { getMe } from "../api";
import { useAuthStore } from "../store";
import { SessionCheck } from "./session-check";

interface AuthGuardProps {
  children: ReactNode;
}

function signInUrl() {
  const { pathname, search } = window.location;
  const path = pathname + search;
  return path === "/" || path === "/notes"
    ? "/login"
    : `/login?returnTo=${encodeURIComponent(path)}`;
}

export function AuthGuard({ children }: AuthGuardProps) {
  const router = useRouter();
  const queryClient = useQueryClient();
  const isAuthenticated = useAuthStore((state) => state.isAuthenticated);
  const isInitialized = useAuthStore((state) => state.isInitialized);
  const hasSignedOut = useAuthStore((state) => state.hasSignedOut);
  const logout = useAuthStore((state) => state.logout);
  const setUser = useAuthStore((state) => state.setUser);

  useEffect(() => {
    const handleUnauthorized = () => logout();
    window.addEventListener("auth:unauthorized", handleUnauthorized);
    return () => {
      window.removeEventListener("auth:unauthorized", handleUnauthorized);
    };
  }, [logout]);

  // The admin's deadline passed during this session: look again, which
  // brings up the setup screen.
  useEffect(() => {
    const handleSecondFactor = () => {
      getMe().then(setUser, () => {});
    };
    window.addEventListener("auth:second-factor", handleSecondFactor);
    return () =>
      window.removeEventListener("auth:second-factor", handleSecondFactor);
  }, [setUser]);

  useEffect(() => {
    if (isInitialized && !isAuthenticated) {
      queryClient.clear();
      router.replace(hasSignedOut ? "/login" : signInUrl());
    }
  }, [isInitialized, isAuthenticated, hasSignedOut, queryClient, router]);

  return <SessionCheck>{isAuthenticated ? children : null}</SessionCheck>;
}
