"use client";

import { useEffect } from "react";
import { type AppStyle, usePreferencesStore } from "@/features/preferences";
import { CUSTOM_THEME_STYLE_ID } from "@/lib/appearance-script";
import { type CustomTheme, customThemeCss } from "@/lib/design/custom-theme";

/**
 * Puts the colour scheme, style, custom theme and high contrast on <html>,
 * where the CSS reads them. A custom theme's colours go in a <style> of
 * their own.
 */
export function applyAppearance(
  scheme: string | undefined,
  style: AppStyle | undefined,
  customTheme?: CustomTheme,
  highContrast?: boolean,
) {
  const html = document.documentElement;
  if (scheme && scheme !== "anchor") html.dataset.scheme = scheme;
  else delete html.dataset.scheme;
  if (style && style !== "default") html.dataset.style = style;
  else delete html.dataset.style;
  if (highContrast !== false) html.dataset.contrast = "high";
  else delete html.dataset.contrast;

  let sheet = document.getElementById(CUSTOM_THEME_STYLE_ID);
  if (customTheme) {
    if (!sheet) {
      sheet = document.createElement("style");
      sheet.id = CUSTOM_THEME_STYLE_ID;
      document.head.appendChild(sheet);
    }
    sheet.textContent = customThemeCss(customTheme);
    html.dataset.customTheme = "";
  } else {
    sheet?.remove();
    delete html.dataset.customTheme;
  }
}

/** Keeps <html> in step with Settings › Appearance. Call once, in the app. */
export function useAppearance() {
  const scheme = usePreferencesStore((s) => s.ui.colorScheme);
  const style = usePreferencesStore((s) => s.ui.style);
  const customTheme = usePreferencesStore((s) => s.ui.customTheme);
  const highContrast = usePreferencesStore((s) => s.ui.highContrast);
  useEffect(
    () => applyAppearance(scheme, style, customTheme, highContrast),
    [scheme, style, customTheme, highContrast],
  );
}
