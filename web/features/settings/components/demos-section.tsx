"use client";

import { ChevronRight, Play } from "lucide-react";
import Link from "next/link";
import { CopyDemoLink } from "@/components/demo/copy-demo-link";
import { demos } from "@/lib/demo/demos";
import { Section } from "./settings-blocks";

/** The demo build's list of feature demos; each plays at its own address. */
export function DemosSection() {
  return (
    <Section
      id="demos"
      title="Feature demos"
      description="Each one plays a short demo with its own sample notes; then it's your turn. Nothing is saved: a reload starts the demo over."
    >
      {demos.map((demo) => (
        <div
          key={demo.slug}
          className="flex min-w-0 items-center gap-1 pr-3 hover:bg-foreground/4 max-md:pr-2"
        >
          <Link
            href={`/${demo.slug}`}
            className="flex min-w-0 flex-1 items-center gap-3.5 py-3.5 pl-5 text-foreground no-underline max-md:py-3.5 max-md:pl-3.5"
          >
            <span className="grid size-8 flex-none place-items-center rounded-full bg-accent-strong/12 text-accent-ink">
              <Play aria-hidden className="size-3.5 fill-current" />
            </span>
            <span className="grid min-w-0 flex-1 gap-0.5">
              <b className="font-semibold text-ui">{demo.title}</b>
              <span className="text-meta text-muted-foreground leading-[1.45]">
                {demo.summary}
              </span>
            </span>
            <ChevronRight
              aria-hidden
              className="size-4 flex-none text-muted-foreground"
            />
          </Link>
          <CopyDemoLink slug={demo.slug} className="flex-none" />
        </div>
      ))}
    </Section>
  );
}
