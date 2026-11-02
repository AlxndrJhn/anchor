"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useEffect } from "react";
import { applyAddons } from "@/lib/addons/apply";
import type { AddonPackage } from "@/lib/addons/manifest";
import { getAddons, installAddon, removeAddon, setAddonEnabled } from "./api";
import type { Addon } from "./types";

const ADDONS_KEY = ["addons"];

/** The addons, or null when the server has none; checked again on focus. */
export function useAddons() {
  return useQuery({
    queryKey: ADDONS_KEY,
    queryFn: getAddons,
    // Installed on another device, an addon turns up on coming back here.
    refetchOnWindowFocus: true,
  });
}

/** Keeps the page in step with the addons that are on. Call once, in the app. */
export function useAppliedAddons() {
  const { data } = useAddons();
  useEffect(() => {
    if (data !== undefined) applyAddons(data ?? []);
  }, [data]);
}

export function useAddonActions() {
  const queryClient = useQueryClient();
  const put = (addon: Addon) =>
    queryClient.setQueryData<Addon[] | null>(ADDONS_KEY, (addons) => {
      const list = addons ?? [];
      return list.some((a) => a.id === addon.id)
        ? list.map((a) => (a.id === addon.id ? addon : a))
        : [...list, addon];
    });
  const install = useMutation({
    mutationFn: (addon: AddonPackage) => installAddon(addon),
    onSuccess: put,
  });
  const setEnabled = useMutation({
    mutationFn: ({ id, enabled }: { id: string; enabled: boolean }) =>
      setAddonEnabled(id, enabled),
    onSuccess: put,
  });
  const remove = useMutation({
    mutationFn: (id: string) => removeAddon(id),
    onSuccess: (_, id) =>
      queryClient.setQueryData<Addon[] | null>(ADDONS_KEY, (addons) =>
        addons?.filter((a) => a.id !== id),
      ),
  });
  return { install, setEnabled, remove };
}
