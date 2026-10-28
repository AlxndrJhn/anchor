import type { QueryClient } from "@tanstack/react-query";
import { create } from "zustand";
import { usePreferencesStore } from "@/features/preferences/store";
import { localServer } from "@/lib/local-backend/install";
import { demoBySlug } from "./demos";
import { buildData, type Seed } from "./seed";

type Status = "idle" | "loading" | "playing" | "done";

interface DemoState {
  slug: string | null;
  status: Status;
  caption: string;
  /** Changes each time a demo starts, so the player starts over. */
  run: number;
  set: (state: Partial<Omit<DemoState, "set">>) => void;
}

export const useDemo = create<DemoState>()((set) => ({
  slug: null,
  status: "idle",
  caption: "",
  run: 0,
  set,
}));

async function load(seed: Seed, queryClient: QueryClient) {
  const { data, files } = buildData(seed);
  await localServer().reset(data, files);
  usePreferencesStore.setState(usePreferencesStore.getInitialState(), true);
  queryClient.clear();
}

/** Loads a demo's notes and plays it; the player takes it from there. */
export async function startDemo(slug: string, queryClient: QueryClient) {
  const demo = demoBySlug(slug);
  if (!demo) return;
  useDemo.getState().set({ status: "loading", slug, caption: demo.title });
  await load(demo.seed, queryClient);
  useDemo.setState((state) => ({
    status: "playing",
    slug,
    caption: demo.title,
    run: state.run + 1,
  }));
}
