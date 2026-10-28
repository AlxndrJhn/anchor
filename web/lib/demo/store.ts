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
  /** The step playing, or the next one while paused. */
  step: number;
  /** Waits before the next step until played on or stepped. */
  paused: boolean;
  /** Paused before `step`, which hasn't started. */
  waiting: boolean;
  /** Plays one more step while paused. */
  advance: boolean;
  /** Plays the steps before this one at once, then pauses: how Back works. */
  skipTo: number;
  set: (state: Partial<Omit<DemoState, "set">>) => void;
}

export const useDemo = create<DemoState>()((set) => ({
  slug: null,
  status: "idle",
  caption: "",
  run: 0,
  step: 0,
  paused: false,
  waiting: false,
  advance: false,
  skipTo: 0,
  set,
}));

async function load(seed: Seed, queryClient: QueryClient) {
  const { data, files } = buildData(seed);
  await localServer().reset(data, files);
  usePreferencesStore.setState(usePreferencesStore.getInitialState(), true);
  queryClient.clear();
}

/**
 * Loads a demo's notes and plays it; the player takes it from there. With
 * `pauseAt`, it hurries through the steps before that one and pauses there.
 */
export async function startDemo(
  slug: string,
  queryClient: QueryClient,
  pauseAt?: number,
) {
  const demo = demoBySlug(slug);
  if (!demo) return;
  useDemo.getState().set({ status: "loading", slug, caption: demo.title });
  await load(demo.seed, queryClient);
  useDemo.setState((state) => ({
    status: "playing",
    slug,
    caption: demo.title,
    run: state.run + 1,
    step: 0,
    paused: pauseAt !== undefined,
    waiting: false,
    advance: false,
    skipTo: pauseAt ?? 0,
  }));
}
