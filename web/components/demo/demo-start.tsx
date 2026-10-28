"use client";

import { useQueryClient } from "@tanstack/react-query";
import { useEffect } from "react";
import { SplashScreen } from "@/components/layout/splash-screen";
import { startDemo } from "@/lib/demo/store";

/** The page of a feature demo: loads its notes, then the player takes over. */
export function DemoStart({ slug }: { slug: string }) {
  const queryClient = useQueryClient();
  useEffect(() => {
    void startDemo(slug, queryClient);
  }, [slug, queryClient]);
  return <SplashScreen checking={false} />;
}
