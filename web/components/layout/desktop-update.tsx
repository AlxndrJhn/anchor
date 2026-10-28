"use client";

import * as React from "react";
import { Button } from "@/components/ui/button";
import { Tip } from "@/components/ui/tooltip";
import { installDesktopUpdate, useDesktopUpdate } from "@/lib/desktop";

/** In the desktop app, once an update is ready: a small "Update" button, as in VS Code. */
export function DesktopUpdateButton({ className }: { className?: string }) {
  const update = useDesktopUpdate();
  const [restarting, setRestarting] = React.useState(false);
  if (!update) return null;
  return (
    <Tip label={`Restart Anchor to update to ${update.version}`}>
      <Button
        size="sm"
        className={className}
        busy={restarting && "Restarting…"}
        onClick={async () => {
          setRestarting(true);
          if (!(await installDesktopUpdate())) setRestarting(false);
        }}
      >
        Update
      </Button>
    </Tip>
  );
}
