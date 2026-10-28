import * as React from "react";

/** An update of the desktop app, downloaded and ready to install. */
export interface DesktopUpdate {
  version: string;
}

/** What the desktop app (desktop/src/preload.js) gives the web client. */
interface AnchorDesktop {
  onUpdate?: (callback: (update: DesktopUpdate) => void) => () => void;
  installUpdate?: () => Promise<boolean>;
}

const desktop = () =>
  typeof window === "undefined"
    ? undefined
    : (window as { anchorDesktop?: AnchorDesktop }).anchorDesktop;

/** The desktop app's ready update; null outside the app or when up to date. */
export function useDesktopUpdate() {
  const [update, setUpdate] = React.useState<DesktopUpdate | null>(null);
  React.useEffect(() => desktop()?.onUpdate?.(setUpdate), []);
  return update;
}

/** Quits the desktop app, installs the update and starts it again. */
export async function installDesktopUpdate() {
  return (await desktop()?.installUpdate?.()) ?? false;
}
