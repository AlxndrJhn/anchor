"use client";

import { useTheme } from "next-themes";
import type * as React from "react";
import { RadioCards } from "@/components/ui/radio-cards";
import { Switch } from "@/components/ui/switch";
import { type AppStyle, usePreferencesStore } from "@/features/preferences";
import { COLOR_SCHEMES, type SchemeSwatch } from "@/lib/design/schemes";
import { switchTheme } from "@/lib/theme";
import { cn } from "@/lib/utils";
import { CustomThemeEditor } from "./custom-theme-editor";
import { Row, RowText, Section } from "./settings-blocks";

function ThemeThumb({ theme }: { theme: "light" | "dark" }) {
  return (
    <div
      className={cn(
        theme,
        "grid h-full grid-cols-[28%_1fr] bg-background text-foreground",
      )}
    >
      <i className="block bg-sidebar" />
      <em className="grid content-start gap-1 p-2 not-italic">
        <s className="block h-1.25 w-3/5 rounded-xs bg-current no-underline opacity-40" />
        <s className="block h-1.25 rounded-xs bg-current no-underline opacity-22" />
        <s className="block h-1.25 rounded-xs bg-current no-underline opacity-22" />
      </em>
    </div>
  );
}

const ANCHOR_SCHEME = {
  id: "anchor",
  name: "Anchor+",
  light: {
    background: "#F0F4F8",
    card: "#FFFFFF",
    foreground: "#2D3142",
    accent: "#EF8354",
  },
  dark: {
    background: "#1C1E26",
    card: "#262A36",
    foreground: "#EAEAEA",
    accent: "#EF8354",
  },
};

/** A scheme in miniature: its page, a card with text, and its accent. */
function SchemeThumb({ swatch }: { swatch: SchemeSwatch }) {
  return (
    <div
      className="relative mb-2 grid h-14 grid-cols-[1fr_1fr] gap-1.5 overflow-hidden rounded-md p-2 shadow-[inset_0_0_0_1px_color-mix(in_srgb,var(--border)_80%,transparent)]"
      style={{ background: swatch.background }}
    >
      <i
        className="grid content-start gap-1 rounded-xs p-1.5"
        style={{ background: swatch.card }}
      >
        <s
          className="block h-1 w-3/4 rounded-xs no-underline opacity-70"
          style={{ background: swatch.foreground }}
        />
        <s
          className="block h-1 rounded-xs no-underline opacity-35"
          style={{ background: swatch.foreground }}
        />
      </i>
      <i
        className="size-4 self-end justify-self-end rounded-full"
        style={{ background: swatch.accent }}
      />
    </div>
  );
}

const STYLES: {
  value: AppStyle;
  label: string;
  description: string;
  picture: React.ReactNode;
}[] = [
  {
    value: "default",
    label: "Default",
    description: "Clean and soft",
    picture: (
      <StyleThumb
        card={{ borderRadius: 8, boxShadow: "0 2px 8px rgb(0 0 0 / .12)" }}
      />
    ),
  },
  {
    value: "skeuomorphism",
    label: "Skeuomorphism",
    description: "Paper, linen and gloss",
    picture: (
      <StyleThumb
        page={{
          backgroundImage:
            "repeating-linear-gradient(0deg, rgb(0 0 0 / .05) 0 1px, transparent 1px 3px)",
        }}
        card={{
          borderRadius: 6,
          backgroundImage:
            "linear-gradient(180deg, rgb(255 255 255 / .5), transparent 45%), repeating-linear-gradient(to bottom, transparent 0 7px, rgb(0 0 0 / .12) 7px 8px)",
          boxShadow: "inset 0 1px 0 #fff, 0 3px 6px rgb(0 0 0 / .3)",
        }}
      />
    ),
  },
  {
    value: "neo-brutalism",
    label: "Neo-Brutalism",
    description: "Bold outlines, hard shadows",
    picture: (
      <StyleThumb
        card={{
          borderRadius: 3,
          border: "2px solid currentColor",
          boxShadow: "3px 3px 0 currentColor",
        }}
      />
    ),
  },
  {
    value: "lofi",
    label: "Lo-fi",
    description: "A pencil sketch, in greys",
    picture: (
      <StyleThumb
        page={{
          backgroundImage:
            "radial-gradient(rgb(0 0 0 / .18) 1px, transparent 1px)",
          backgroundSize: "8px 8px",
          filter: "grayscale(1)",
        }}
        card={{
          borderRadius: "255px 8px 225px 8px / 8px 225px 8px 255px",
          border: "1.5px solid currentColor",
          background: "transparent",
        }}
      />
    ),
  },
];

/** A style in miniature: one card on a page. */
function StyleThumb({
  page,
  card,
}: {
  page?: React.CSSProperties;
  card: React.CSSProperties;
}) {
  return (
    <div
      className="relative mb-2 grid h-14 place-items-center overflow-hidden rounded-md bg-background text-foreground shadow-[inset_0_0_0_1px_color-mix(in_srgb,var(--border)_80%,transparent)]"
      style={page}
    >
      <i className="block h-8 w-16 bg-card" style={card} />
    </div>
  );
}

function SchemeAndStyle() {
  const { resolvedTheme } = useTheme();
  const mode = resolvedTheme === "dark" ? "dark" : "light";
  const scheme = usePreferencesStore((s) => s.ui.colorScheme ?? "anchor");
  const style = usePreferencesStore((s) => s.ui.style ?? "default");
  const highContrast = usePreferencesStore((s) => s.ui.highContrast !== false);
  const setUI = usePreferencesStore((s) => s.setUIPreference);
  return (
    <>
      <Row className="grid items-start gap-3.5">
        <RowText
          title="Colour scheme"
          text={
            style === "lofi"
              ? "Lo-fi draws in its own greys; the scheme comes back with another style."
              : "Popular palettes, each in a light and a dark version."
          }
        />
        <RadioCards
          aria-label="Colour scheme"
          value={scheme}
          onValueChange={(value) => setUI("colorScheme", value)}
          className="grid-cols-[repeat(auto-fill,minmax(128px,1fr))]"
          options={[ANCHOR_SCHEME, ...COLOR_SCHEMES].map((option) => ({
            value: option.id,
            label: option.name,
            picture: <SchemeThumb swatch={option[mode]} />,
          }))}
        />
      </Row>
      <CustomThemeEditor />
      <Row className="grid items-start gap-3.5">
        <RowText title="Style" text="Shapes, shadows and type." />
        <RadioCards
          aria-label="Style"
          value={style}
          onValueChange={(value) => setUI("style", value)}
          className="grid-cols-4 max-md:grid-cols-2"
          options={STYLES}
        />
      </Row>
      <Row>
        <RowText
          title={<label htmlFor="high-contrast">High contrast</label>}
          text="Darker text and a little bolder note text, with any colour scheme."
        />
        <Switch
          id="high-contrast"
          checked={highContrast}
          onCheckedChange={(on) => setUI("highContrast", on)}
        />
      </Row>
    </>
  );
}

export function AppearanceSection() {
  const { theme = "system", setTheme } = useTheme();
  const frameClass =
    "relative mb-2 h-16 overflow-hidden rounded-md shadow-[inset_0_0_0_1px_color-mix(in_srgb,var(--border)_80%,transparent)]";
  return (
    <Section id="appearance" title="Appearance">
      <Row className="grid items-start gap-3.5">
        <RowText title="Theme" text="Choose how Anchor+ looks." />
        <RadioCards
          aria-label="Theme"
          value={theme as "light" | "dark" | "system"}
          onValueChange={(v) => switchTheme(v, setTheme)}
          className="grid-cols-3 max-md:grid-cols-1"
          options={[
            {
              value: "light",
              label: "Light",
              description: "Always light",
              picture: (
                <div className={frameClass}>
                  <ThemeThumb theme="light" />
                </div>
              ),
            },
            {
              value: "dark",
              label: "Dark",
              description: "Always dark",
              picture: (
                <div className={frameClass}>
                  <ThemeThumb theme="dark" />
                </div>
              ),
            },
            {
              value: "system",
              label: "Match system",
              description: "Follows your device",
              picture: (
                <div className={frameClass}>
                  <div className="absolute inset-0">
                    <ThemeThumb theme="light" />
                  </div>
                  <div className="absolute inset-0 [clip-path:polygon(64%_0,100%_0,100%_100%,36%_100%)]">
                    <ThemeThumb theme="dark" />
                  </div>
                </div>
              ),
            },
          ]}
        />
      </Row>
      <SchemeAndStyle />
    </Section>
  );
}
