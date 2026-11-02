"use client";

import { useEffect } from "react";

/** The app's name, after each page's own in the browser tab. */
export const APP_TITLE = "Anchor+";

/** "Notes · Anchor+", as the root layout's title template writes it. */
export const documentTitle = (title?: string) =>
  title ? `${title} · ${APP_TITLE}` : APP_TITLE;

/**
 * Names the page in the browser tab (WCAG 2.4.2). Most pages are client
 * components, so they can't give Next their title as metadata.
 */
export function useDocumentTitle(title: string | undefined) {
  useEffect(() => {
    if (title === undefined) return;
    document.title = documentTitle(title);
  }, [title]);
}
