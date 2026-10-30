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

/** The address of a feature without a demo: its entry in the demo list. */
export function featureUrl(slug: string) {
  return new URL(publicPath(`/demos#feature-${slug}`), window.location.origin)
    .href;
}

/** Copies the address of a feature demo, or of a feature's entry. */
export function CopyDemoLink({
  slug,
  feature = false,
  className,
}: {
  slug: string;
  /** A feature without a demo: links to its entry in the list. */
  feature?: boolean;
  className?: string;
}) {
  const label = feature
    ? "Copy link to this feature"
    : "Copy link to this demo";
  return (
    <IconButton
      size="sm"
      label={label}
      title={label}
      className={className}
      onClick={() =>
        copyText(feature ? featureUrl(slug) : demoUrl(slug)).then(
          () => toast.success("Link copied"),
          () => toast.error("Couldn’t copy the link"),
        )
      }
    >
      <Link2 />
    </IconButton>
  );
}
