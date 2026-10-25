"use client";

import { useEffect } from "react";
import { type AppStyle, usePreferencesStore } from "@/features/preferences";

/** Puts the colour scheme and style on <html>, where the CSS reads them. */
export function applyAppearance(
  scheme: string | undefined,
  style: AppStyle | undefined,
) {
  const html = document.documentElement;
  if (scheme && scheme !== "anchor") html.dataset.scheme = scheme;
  else delete html.dataset.scheme;
  if (style && style !== "default") html.dataset.style = style;
  else delete html.dataset.style;
}

/** Keeps <html> in step with Settings › Appearance. Call once, in the app. */
export function useAppearance() {
  const scheme = usePreferencesStore((s) => s.ui.colorScheme);
  const style = usePreferencesStore((s) => s.ui.style);
  useEffect(() => applyAppearance(scheme, style), [scheme, style]);
}
