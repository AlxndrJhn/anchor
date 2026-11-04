"use client";

import { useQuery } from "@tanstack/react-query";
import { Download, Link2 } from "lucide-react";
import * as React from "react";
import { Button } from "@/components/ui/button";
import { QrImage } from "@/components/ui/qr-image";
import { SegmentedControl } from "@/components/ui/segmented-control";
import { TabPanel, Tabs } from "@/components/ui/tabs";
import { toast } from "@/components/ui/toast";
import { copyText } from "@/lib/clipboard";
import {
  type ApkRelease,
  fetchApkReleases,
  LATEST_APK_URL,
} from "../utils/apk-releases";
import { MagicLoginPanel } from "./magic-login-section";
import { Section } from "./settings-blocks";

type PhoneTab = "app" | "sign-in";
type Channel = "stable" | "candidate";

const PANEL_ID = "phone-panel";
const TABS = [
  { value: "app", label: "1. Get the app" },
  { value: "sign-in", label: "2. Sign in" },
] as const;

/**
 * Connecting a phone, in the order it happens: download the Android app from
 * its GitHub release, then sign in to it with a magic login QR code.
 */
export function PhoneSection() {
  const [tab, setTab] = React.useState<PhoneTab>("app");
  return (
    <Section
      id="phone"
      title="Connect your phone"
      description="Install the Anchor+ Android app, then sign in to it without a password."
    >
      <div className="px-4 pt-1.5 max-md:px-2.5">
        <Tabs
          value={tab}
          onValueChange={setTab}
          tabs={TABS}
          panelId={PANEL_ID}
          aria-label="Connect your phone"
          className="mb-0"
        />
      </div>
      <TabPanel id={PANEL_ID} labelledBy={`${PANEL_ID}-tab-${tab}`}>
        {tab === "app" ? <AppDownloadPanel /> : <MagicLoginPanel />}
      </TabPanel>
    </Section>
  );
}

function AppDownloadPanel() {
  const [channel, setChannel] = React.useState<Channel>("stable");
  const releases = useQuery({
    queryKey: ["apk-releases"],
    queryFn: fetchApkReleases,
    staleTime: 30 * 60 * 1000,
    retry: 1,
  });
  const candidate = releases.data?.candidate;
  const chosen: ApkRelease | null =
    channel === "candidate" && candidate
      ? candidate
      : (releases.data?.stable ?? null);
  // Without GitHub's answer, the newest stable release still has a link.
  const url = chosen?.url ?? LATEST_APK_URL;

  const copy = () =>
    copyText(url).then(
      () => toast.success("Download link copied"),
      () => toast.error("Couldn’t copy the download link"),
    );

  return (
    <div className="flex flex-wrap items-start gap-6 px-5 py-4 max-md:p-3.5">
      <div className="w-44 flex-none max-md:mx-auto">
        <QrImage text={url} label="QR code to download the Android app" />
      </div>
      <div className="grid min-w-50 flex-1 gap-3">
        <div className="grid gap-0.5">
          <b className="font-semibold text-ui">Download the Android app</b>
          <span className="text-meta text-muted-foreground leading-[1.45]">
            Scan the code with your phone’s camera to download the APK, then
            open it to install. Android may ask you to allow installs from your
            browser first.
          </span>
        </div>
        {candidate && (
          <SegmentedControl
            aria-label="Release"
            size="sm"
            value={channel}
            onValueChange={setChannel}
            options={[
              { value: "stable", label: "Latest release" },
              { value: "candidate", label: "Release candidate" },
            ]}
          />
        )}
        <p
          role="status"
          className="m-0 text-meta text-muted-foreground leading-[1.45]"
        >
          {releases.isPending
            ? "Looking up the newest version…"
            : chosen
              ? channel === "candidate" && candidate
                ? `Anchor+ ${chosen.version}, a preview of the next release. It may still have rough edges.`
                : `Anchor+ ${chosen.version}`
              : "The newest release."}
        </p>
        <div className="flex flex-wrap items-center gap-2">
          <Button variant="secondary" asChild>
            <a href={url} download>
              <Download aria-hidden />
              Download APK
            </a>
          </Button>
          <Button variant="secondary" onClick={copy}>
            <Link2 aria-hidden />
            Copy link
          </Button>
        </div>
      </div>
    </div>
  );
}
