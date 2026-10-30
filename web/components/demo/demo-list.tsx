"use client";

import { ChevronRight, ExternalLink, Info, Play, Search } from "lucide-react";
import Link from "next/link";
import * as React from "react";
import { CopyDemoLink } from "@/components/demo/copy-demo-link";
import { Input } from "@/components/ui/input";
import { Section } from "@/features/settings";
import { demos } from "@/lib/demo/demos";
import { features } from "@/lib/demo/features";
import { prefersReducedMotion } from "@/lib/motion";
import { cn } from "@/lib/utils";

const HIGHLIGHT_MS = 2000;

/** The slug in a #feature-<slug> address, if it names a feature. */
function linkedFeature() {
  const slug = window.location.hash.replace(/^#feature-/, "");
  return features.some((feature) => feature.slug === slug) ? slug : null;
}

/**
 * The demo build's list of feature demos; each plays at its own address.
 * Features that can't be demoed follow, each linked at #feature-<slug>.
 */
export function DemoList() {
  const [query, setQuery] = React.useState("");
  const [highlighted, setHighlighted] = React.useState<string | null>(null);
  // Every word has to appear in the title or summary.
  const words = query.toLowerCase().split(/\s+/).filter(Boolean);
  const matches = (item: { title: string; summary: string }) => {
    const text = `${item.title} ${item.summary}`.toLowerCase();
    return words.every((word) => text.includes(word));
  };
  const shownDemos = demos.filter(matches);
  const shownFeatures = features.filter(matches);

  // A link to a feature clears the search, so its entry is there to show.
  React.useEffect(() => {
    const follow = () => {
      const slug = linkedFeature();
      if (!slug) return;
      setQuery("");
      setHighlighted(slug);
    };
    follow();
    window.addEventListener("hashchange", follow);
    return () => window.removeEventListener("hashchange", follow);
  }, []);

  React.useEffect(() => {
    if (!highlighted) return;
    document.getElementById(`feature-${highlighted}`)?.scrollIntoView({
      behavior: prefersReducedMotion() ? "auto" : "smooth",
      block: "center",
    });
    const timer = window.setTimeout(() => setHighlighted(null), HIGHLIGHT_MS);
    return () => window.clearTimeout(timer);
  }, [highlighted]);

  return (
    <div className="grid max-w-160 gap-8 pt-1">
      <Input
        type="search"
        icon={<Search aria-hidden />}
        placeholder="Find a feature"
        aria-label="Find a feature"
        value={query}
        onChange={(e) => setQuery(e.target.value)}
        boxClassName="h-10 w-full"
      />
      {shownDemos.length > 0 && (
        <Section
          id="demos"
          title="Play a demo"
          description="Each one plays a short demo with its own sample notes; then it's your turn. Nothing is saved: a reload starts the demo over."
        >
          {shownDemos.map((demo) => (
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
      )}
      {shownFeatures.length > 0 && (
        <Section
          id="no-demo"
          title="Without a demo"
          description="These need a server or another app, so there's nothing to play here."
        >
          {shownFeatures.map((feature) => (
            <div
              key={feature.slug}
              id={`feature-${feature.slug}`}
              className={cn(
                "flex min-w-0 scroll-mt-4 items-center gap-1 pr-3 transition-colors duration-700 max-md:pr-2",
                highlighted === feature.slug &&
                  "bg-accent-strong/14 duration-150",
              )}
            >
              <div className="flex min-w-0 flex-1 items-center gap-3.5 py-3.5 pl-5 max-md:pl-3.5">
                <span className="grid size-8 flex-none place-items-center rounded-full bg-foreground/6 text-muted-foreground">
                  <Info aria-hidden className="size-4" />
                </span>
                <span className="grid min-w-0 flex-1 gap-0.5">
                  <b className="font-semibold text-ui">{feature.title}</b>
                  <span className="text-meta text-muted-foreground leading-[1.45]">
                    {feature.summary}
                  </span>
                  <span className="text-meta text-muted-foreground/80 italic">
                    {feature.needs}.
                  </span>
                  {feature.link && (
                    <a
                      href={feature.link.href}
                      target="_blank"
                      rel="noreferrer"
                      className="inline-flex w-fit items-center gap-1 text-meta"
                    >
                      {feature.link.label}
                      <ExternalLink aria-hidden className="size-3" />
                    </a>
                  )}
                </span>
              </div>
              <CopyDemoLink slug={feature.slug} feature className="flex-none" />
            </div>
          ))}
        </Section>
      )}
      {shownDemos.length + shownFeatures.length === 0 && (
        <p className="m-0 px-1 text-control text-muted-foreground">
          No feature matches “{query.trim()}”.
        </p>
      )}
    </div>
  );
}
