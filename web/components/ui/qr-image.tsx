"use client";

import * as React from "react";
import { encode } from "uqr";

/** Black on white in either theme, as scanners read it best. */
export function QrImage({ text, label }: { text: string; label: string }) {
  const { path, size } = React.useMemo(() => {
    const { data, size } = encode(text, { ecc: "M", border: 2 });
    const path = data
      .flatMap((row, y) =>
        row.flatMap((isDark, x) => (isDark ? [`M${x} ${y}h1v1h-1z`] : [])),
      )
      .join("");
    return { path, size };
  }, [text]);
  return (
    <svg
      role="img"
      aria-label={label}
      viewBox={`0 0 ${size} ${size}`}
      shapeRendering="crispEdges"
      className="mx-auto block aspect-square w-full max-w-64 rounded-lg bg-white"
    >
      <path d={path} fill="#000" />
    </svg>
  );
}
