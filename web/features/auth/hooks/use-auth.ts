"use client";

import { useMutation, useQuery } from "@tanstack/react-query";
import { HTTPError } from "ky";
import { useCallback } from "react";
import { toast } from "@/components/ui/toast";
import { firstName } from "@/lib/utils";
import {
  getMe,
  getRegistrationMode,
  login as loginApi,
  register as registerApi,
  revokeRefreshToken,
} from "../api";
import { getRefreshToken, hasAccessToken, useAuthStore } from "../store";
import type { LoginCredentials, RegisterCredentials } from "../types";

async function initialize() {
  const { isInitialized, setUser, setInitialized, setUnreachable, logout } =
    useAuthStore.getState();
  if (isInitialized && !useAuthStore.getState().unreachable) return;

  if (!hasAccessToken()) {
    logout();
    return;
  }

  // Known to be offline: don't wait for the request's retries to give up.
  if (!navigator.onLine && useAuthStore.getState().user) {
    setUnreachable(true);
    setInitialized(true);
    window.addEventListener("online", () => void initialize(), { once: true });
    return;
  }

  try {
    const user = await getMe();
    setUnreachable(false);
    setUser(user);
    setInitialized(true);
  } catch (error) {
    if (
      error instanceof HTTPError &&
      (error.response.status === 401 || error.response.status === 403)
    )
      logout();
    else {
      setUnreachable(true);
      // Offline with a session kept on this device: work from what it holds,
      // and check the session again once the connection is back.
      if (!(error instanceof HTTPError) && useAuthStore.getState().user) {
        setInitialized(true);
        window.addEventListener("online", () => void initialize(), {
          once: true,
        });
      }
    }
  }
}

export function useAuth() {
  const {
    user,
    isAuthenticated,
    isInitialized,
    unreachable,
    logout: clearAuth,
  } = useAuthStore();

  const logout = useCallback(async () => {
    try {
      await revokeRefreshToken(getRefreshToken());
    } catch {
      // Sign out locally anyway.
    }
    clearAuth({ hasSignedOut: true });
  }, [clearAuth]);

  return {
    user,
    isAuthenticated,
    isInitialized,
    unreachable,
    initialize,
    logout,
  };
}

export function useRegistrationMode() {
  return useQuery({
    queryKey: ["registration-mode"],
    queryFn: getRegistrationMode,
    retryOnMount: false,
  });
}

export function useLogin() {
  const setAuth = useAuthStore((state) => state.setAuth);
  return useMutation({
    mutationFn: (credentials: LoginCredentials) => loginApi(credentials),
    onSuccess: (data) => {
      if (data.access_token && data.refresh_token) {
        setAuth(data.user, data.access_token, data.refresh_token);
        toast.success(`Welcome back, ${firstName(data.user.name)}`);
      }
    },
  });
}

export function useRegister() {
  const setAuth = useAuthStore((state) => state.setAuth);
  return useMutation({
    mutationFn: (credentials: RegisterCredentials) => registerApi(credentials),
    onSuccess: (data) => {
      // A pending account gets no tokens.
      if (data.access_token && data.refresh_token) {
        setAuth(data.user, data.access_token, data.refresh_token);
        toast.success(`Welcome to Anchor+, ${firstName(data.user.name)}`);
      }
    },
  });
}
