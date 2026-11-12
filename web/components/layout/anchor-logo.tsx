"use client";

import { useId } from "react";
import { cn } from "@/lib/utils";

/** The app icon, in its 1024 by 1024 units: mobile/tool/launcher_icon/icon.js's. */
export function AnchorLogo({ className }: { className?: string }) {
  const id = useId();
  const sea = `${id}sea`;
  const page = `${id}page`;
  return (
    <svg
      viewBox="0 0 1024 1024"
      aria-hidden
      className={cn("flex-none rounded-sm shadow-edge", className)}
    >
      <defs>
        <linearGradient
          id={sea}
          gradientUnits="userSpaceOnUse"
          x1="0"
          y1="0"
          x2="1024"
          y2="1024"
        >
          <stop className="[stop-color:#13687a] dark:[stop-color:#0f4f5e]" />
          <stop
            offset="1"
            className="[stop-color:#0b3b4a] dark:[stop-color:#06222b]"
          />
        </linearGradient>
        <clipPath id={page}>
          <rect width="1024" height="1024" rx="256" />
        </clipPath>
      </defs>
      <g clipPath={`url(#${page})`}>
        <rect width="1024" height="1024" fill={`url(#${sea})`} />
        <g
          fill="none"
          strokeWidth="72"
          strokeLinecap="round"
          strokeLinejoin="round"
        >
          <path
            d="M512 428V788M272 548A240 240 0 0 0 752 548M272 548H344M752 548H680"
            className="stroke-[#f4f1e8] dark:stroke-[#e9ece8]"
          />
          {/* The + of Anchor+, the anchor's ring. */}
          <path d="M512 236V404M428 320H596" stroke="#f2b544" />
        </g>
      </g>
    </svg>
  );
}
