"use client";

import { Link2 } from "lucide-react";
import { IconButton } from "@/components/ui/button";
import { toast } from "@/components/ui/toast";
import { copyText } from "@/lib/clipboard";
import { publicPath } from "@/lib/local-backend/mode";

/** The address a feature demo plays at, to send to someone. */
export function demoUrl(slug: string) {
  return new URL(publicPath(`/${slug}`), window.location.origin).href;
}

/** Copies the address of a feature demo. */
export function CopyDemoLink({
  slug,
  className,
}: {
  slug: string;
  className?: string;
}) {
  return (
    <IconButton
      size="sm"
      label="Copy link to this demo"
      title="Copy link to this demo"
      className={className}
      onClick={() =>
        copyText(demoUrl(slug)).then(
          () => toast.success("Link copied"),
          () => toast.error("Couldn’t copy the link"),
        )
      }
    >
      <Link2 />
    </IconButton>
  );
}
