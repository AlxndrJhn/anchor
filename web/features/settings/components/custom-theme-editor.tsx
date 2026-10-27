"use client";

import { CircleAlert } from "lucide-react";
import * as React from "react";
import { Button } from "@/components/ui/button";
import { toast } from "@/components/ui/toast";
import { usePreferencesStore } from "@/features/preferences";
import { copyText } from "@/lib/clipboard";
import { parseCustomTheme, themeAsJson } from "@/lib/design/custom-theme";
import { Row, RowText } from "./settings-blocks";

/**
 * Settings › Appearance › Custom theme: colours pasted as JSON, kept on this
 * device, over the chosen colour scheme.
 */
export function CustomThemeEditor() {
  const scheme = usePreferencesStore((s) => s.ui.colorScheme ?? "anchor");
  const style = usePreferencesStore((s) => s.ui.style ?? "default");
  const customTheme = usePreferencesStore((s) => s.ui.customTheme);
  const setUI = usePreferencesStore((s) => s.setUIPreference);
  const [text, setText] = React.useState(() =>
    customTheme ? JSON.stringify(customTheme, null, 2) : "",
  );
  const [errors, setErrors] = React.useState<string[]>([]);
  const errorsId = React.useId();

  const apply = () => {
    const result = parseCustomTheme(text);
    if (!result.ok) {
      setErrors(result.errors);
      return;
    }
    setErrors([]);
    setUI("customTheme", result.theme);
    toast.success(
      result.theme.name
        ? `Custom theme “${result.theme.name}” applied`
        : "Custom theme applied",
    );
  };

  const reset = () => {
    setErrors([]);
    setText("");
    setUI("customTheme", undefined);
  };

  const copy = async () => {
    const json = themeAsJson(scheme, customTheme);
    setText(json);
    setErrors([]);
    try {
      await copyText(json);
      toast.success("Current theme copied as JSON");
    } catch {
      toast.info("The current theme is in the box below; copy it from there");
    }
  };

  return (
    <Row className="grid items-start gap-3.5">
      <RowText
        title="Custom theme"
        text={
          <>
            Paste a theme as JSON: colours for light, dark or both. Anything
            left out keeps the colour scheme’s colour. Kept on this device; the
            same JSON works in the Android app.
            {customTheme &&
              (style === "lofi"
                ? " Lo-fi draws in its own greys, so the custom theme waits for another style."
                : ` Applied${customTheme.name ? `: ${customTheme.name}` : ""}.`)}
          </>
        }
      />
      <textarea
        aria-label="Custom theme JSON"
        aria-invalid={errors.length > 0 || undefined}
        aria-describedby={errors.length ? errorsId : undefined}
        value={text}
        onChange={(event) => setText(event.target.value)}
        spellCheck={false}
        rows={8}
        placeholder={
          '{\n  "name": "My theme",\n  "dark": { "background": "#000000", "accent": "#ef8354" }\n}'
        }
        className="min-h-40 w-full resize-y rounded-field bg-card p-3 font-mono text-foreground text-meta shadow-[inset_0_0_0_1px_var(--input)] outline-none placeholder:text-muted-foreground focus-visible:shadow-[inset_0_0_0_2px_var(--ring)] aria-invalid:shadow-[inset_0_0_0_2px_var(--destructive)]"
      />
      {errors.length > 0 && (
        <ul
          id={errorsId}
          role="alert"
          className="m-0 grid list-none gap-1 p-0 text-destructive text-small"
        >
          {errors.map((error) => (
            <li key={error} className="flex items-start gap-1.5">
              <CircleAlert aria-hidden className="mt-0.5 size-3.5 flex-none" />
              <span className="break-words">{error}</span>
            </li>
          ))}
        </ul>
      )}
      <div className="flex flex-wrap gap-2">
        <Button onClick={apply} disabled={!text.trim()}>
          Apply
        </Button>
        <Button variant="secondary" onClick={reset} disabled={!customTheme}>
          Reset
        </Button>
        <Button variant="quiet" onClick={copy}>
          Copy current theme as JSON
        </Button>
      </div>
    </Row>
  );
}
