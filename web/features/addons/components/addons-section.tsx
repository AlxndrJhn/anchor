"use client";

import { FileUp, Link2, Puzzle, ShieldCheck, Trash2 } from "lucide-react";
import * as React from "react";
import { Badge } from "@/components/ui/badge";
import { Button, IconButton } from "@/components/ui/button";
import { ConfirmationDialog } from "@/components/ui/confirmation-dialog";
import { LoadFailedRow } from "@/components/ui/empty-state";
import { Input } from "@/components/ui/input";
import { Skeleton } from "@/components/ui/skeleton";
import { Switch } from "@/components/ui/switch";
import { toast } from "@/components/ui/toast";
import { Row, RowText, Section } from "@/features/settings";
import { isSafeMode, leaveSafeMode } from "@/lib/addons/apply";
import type { AddonCheck } from "@/lib/addons/manifest";
import { fetchAddon, readAddon } from "@/lib/addons/read";
import { useAddonActions, useAddons } from "../hooks";
import type { Addon } from "../types";

const GUIDE =
  "https://github.com/AlxndrJhn/anchor/blob/main/design/addons.md#the-addon-package";

/** What an addon brings, in a few words. */
function brings(addon: Addon) {
  const { theme, styles } = addon.manifest.contributes;
  return [theme && "colours", styles?.length && "styles"]
    .filter(Boolean)
    .join(" and ");
}

/** The accents an addon's theme sets, as dots. */
function ThemeDots({ addon }: { addon: Addon }) {
  const theme = addon.manifest.contributes.theme;
  const colours = [
    ...new Set([theme?.light?.accent, theme?.dark?.accent]),
  ].filter((c): c is string => !!c);
  if (!colours.length) return null;
  return (
    <span className="inline-flex gap-1" aria-hidden>
      {colours.map((colour) => (
        <i
          key={colour}
          className="size-3 rounded-full shadow-[inset_0_0_0_1px_color-mix(in_srgb,var(--foreground)_18%,transparent)]"
          style={{ background: colour }}
        />
      ))}
    </span>
  );
}

function AddonRow({
  addon,
  onRemove,
}: {
  addon: Addon;
  onRemove: (addon: Addon) => void;
}) {
  const { setEnabled } = useAddonActions();
  const { manifest } = addon;
  const switchId = `addon-${addon.id}`;
  return (
    <Row data-addon={addon.addonId}>
      <RowText
        title={
          <>
            <label htmlFor={switchId}>{manifest.name}</label>
            <Badge>{addon.version}</Badge>
            <ThemeDots addon={addon} />
          </>
        }
        text={
          <>
            {manifest.description && <>{manifest.description} </>}
            <span className="block">
              Brings {brings(addon)}
              {manifest.author && <> · by {manifest.author}</>}
              {manifest.homepage && (
                <>
                  {" · "}
                  <a
                    href={manifest.homepage}
                    target="_blank"
                    rel="noreferrer noopener"
                    className="font-semibold text-accent-ink underline decoration-current/35 underline-offset-3 hover:decoration-current"
                  >
                    Website
                  </a>
                </>
              )}
            </span>
          </>
        }
      />
      <span className="flex items-center gap-2">
        <IconButton
          size="sm"
          tone="danger"
          label={`Remove ${manifest.name}`}
          onClick={() => onRemove(addon)}
        >
          <Trash2 aria-hidden />
        </IconButton>
        <Switch
          id={switchId}
          checked={addon.enabled}
          disabled={setEnabled.isPending}
          onCheckedChange={(enabled) =>
            setEnabled.mutate(
              { id: addon.id, enabled },
              {
                onError: () =>
                  toast.error(
                    `Couldn’t turn ${manifest.name} ${enabled ? "on" : "off"}`,
                  ),
              },
            )
          }
        />
      </span>
    </Row>
  );
}

function InstallRow({ addons }: { addons: Addon[] }) {
  const { install } = useAddonActions();
  const fileInput = React.useRef<HTMLInputElement>(null);
  const [url, setUrl] = React.useState("");
  const [reading, setReading] = React.useState(false);
  const [errors, setErrors] = React.useState<string[]>([]);

  const installChecked = (check: AddonCheck) => {
    if (!check.ok) {
      setErrors(check.errors);
      return;
    }
    setErrors([]);
    const { manifest } = check.addon;
    const before = addons.find((a) => a.addonId === manifest.id);
    install.mutate(check.addon, {
      onSuccess: () => {
        setUrl("");
        toast.success(
          before
            ? `${manifest.name} updated to ${manifest.version}`
            : `${manifest.name} installed`,
        );
      },
      onError: async (error) => {
        const body = await (error as { response?: Response }).response
          ?.json()
          .catch(() => undefined);
        setErrors(
          body?.errors ?? [body?.message ?? "Couldn’t install the addon"],
        );
      },
    });
  };

  const fromFile = async (file: File | undefined) => {
    if (!file) return;
    setReading(true);
    try {
      installChecked(
        readAddon(file.name, new Uint8Array(await file.arrayBuffer())),
      );
    } finally {
      setReading(false);
      if (fileInput.current) fileInput.current.value = "";
    }
  };

  const fromUrl = async (event: React.FormEvent) => {
    event.preventDefault();
    if (!url.trim()) return;
    setReading(true);
    try {
      installChecked(await fetchAddon(url.trim()));
    } finally {
      setReading(false);
    }
  };

  const busy = reading || install.isPending;
  return (
    <Row className="grid gap-3">
      <RowText
        title="Install an addon"
        text={
          <>
            An addon’s .zip, or its addon.json, from a file or an address.
            Addons follow you to your other devices.{" "}
            <a
              href={GUIDE}
              target="_blank"
              rel="noreferrer noopener"
              className="font-semibold text-accent-ink underline decoration-current/35 underline-offset-3 hover:decoration-current"
            >
              Make your own
            </a>
          </>
        }
      />
      <form className="flex flex-wrap items-center gap-2" onSubmit={fromUrl}>
        <Input
          className="min-w-56 flex-1"
          type="url"
          inputMode="url"
          placeholder="https://…/my-addon.zip"
          aria-label="Addon address"
          value={url}
          onChange={(event) => setUrl(event.target.value)}
          icon={<Link2 aria-hidden />}
        />
        <Button
          type="submit"
          variant="secondary"
          disabled={!url.trim()}
          busy={busy && !!url.trim() && "Installing…"}
        >
          Install
        </Button>
        <Button
          type="button"
          variant="secondary"
          onClick={() => fileInput.current?.click()}
          busy={busy && !url.trim() && "Installing…"}
        >
          <FileUp aria-hidden />
          Choose file
        </Button>
        <input
          ref={fileInput}
          type="file"
          accept=".zip,.json,application/zip,application/json"
          hidden
          onChange={(event) => fromFile(event.target.files?.[0])}
        />
      </form>
      {errors.length > 0 && (
        <div role="alert" className="grid gap-1 text-destructive text-meta">
          <b className="font-semibold">This addon can’t be installed:</b>
          <ul className="m-0 grid gap-0.5 pl-4">
            {errors.map((error) => (
              <li key={error}>{error}</li>
            ))}
          </ul>
        </div>
      )}
    </Row>
  );
}

export function AddonsSection() {
  const query = useAddons();
  const { remove } = useAddonActions();
  const [removing, setRemoving] = React.useState<Addon | null>(null);
  const [safe] = React.useState(isSafeMode);
  const addons = query.data ?? [];

  return (
    <Section
      id="addons"
      title="Addons"
      description="Colours and styles others made, or you did."
    >
      {safe && (
        <Row>
          <ShieldCheck aria-hidden className="size-5 text-muted-foreground" />
          <RowText
            title="Safe mode"
            text="Addons are off in this tab, as it was opened with ?safe. Turn off or remove the one that gets in the way."
          />
          <Button variant="secondary" onClick={leaveSafeMode}>
            Turn addons back on
          </Button>
        </Row>
      )}
      {query.isError ? (
        <Row>
          <LoadFailedRow
            className="flex-1"
            message="Couldn’t load your addons."
            onRetry={() => query.refetch()}
            isRetrying={query.isFetching}
          />
        </Row>
      ) : query.isLoading ? (
        <Row className="grid gap-3" aria-busy="true">
          <Skeleton className="h-4 w-1/3" />
          <Skeleton className="h-3 w-2/3" />
        </Row>
      ) : query.data === null ? (
        <Row>
          <Puzzle aria-hidden className="size-5 text-muted-foreground" />
          <RowText
            title="Not on this server"
            text="Addons are kept on an Anchor+ server; this one is upstream Anchor’s."
          />
        </Row>
      ) : (
        <>
          {addons.map((addon) => (
            <AddonRow key={addon.id} addon={addon} onRemove={setRemoving} />
          ))}
          <InstallRow addons={addons} />
        </>
      )}
      <ConfirmationDialog
        open={!!removing}
        onOpenChange={(open) => !open && setRemoving(null)}
        title={`Remove ${removing?.manifest.name ?? "the addon"}?`}
        description="It goes from all your devices. You can install it again."
        confirmLabel="Remove"
        busyLabel="Removing…"
        variant="destructive"
        isPending={remove.isPending}
        onConfirm={() =>
          removing &&
          remove.mutate(removing.id, {
            onSuccess: () => setRemoving(null),
            onError: () => toast.error("Couldn’t remove the addon"),
          })
        }
      />
    </Section>
  );
}
