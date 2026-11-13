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
        {/* A note card, tilted, with a title line and the anchor. */}
        <g transform="rotate(-6 512 520)">
          <rect
            x="196"
            y="150"
            width="632"
            height="740"
            rx="80"
            className="fill-[#f4f1e8] dark:fill-[#dfe3df]"
          />
          <rect
            x="290"
            y="236"
            width="300"
            height="44"
            rx="22"
            className="fill-[#cfd8d6] dark:fill-[#bcc6c4]"
          />
          <g
            fill="none"
            strokeWidth="47.5"
            strokeLinecap="round"
            strokeLinejoin="round"
          >
            <path
              d="M512 534.6V772.2M353.6 613.8A158.4 158.4 0 0 0 670.4 613.8M353.6 613.8H401.1M670.4 613.8H622.9"
              stroke="#0b3b4a"
            />
            {/* The + of Anchor+, the anchor's ring. */}
            <path d="M512 407.8V518.7M456.6 463.3H567.4" stroke="#d9961c" />
          </g>
        </g>
      </g>
    </svg>
  );
}
