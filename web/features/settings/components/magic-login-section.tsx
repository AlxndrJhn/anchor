"use client";

import { useMutation, useQuery } from "@tanstack/react-query";
import { Link2, QrCode, RotateCw } from "lucide-react";
import * as React from "react";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogBody,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { QrImage } from "@/components/ui/qr-image";
import { toast } from "@/components/ui/toast";
import { createMagicLogin, listSessions } from "@/features/auth/api";
import type { MagicLoginCode } from "@/features/auth/types";
import { magicLinkUrl } from "@/features/auth/utils/magic-link";
import { copyText } from "@/lib/clipboard";
import { sessionsKey } from "./devices-section";
import { flyQrTo, waitForScan } from "./scan-handoff";
import { Row, RowText } from "./settings-blocks";

// Looks for the phone signing in more often while the QR code shows, so the
// code flies to it soon after the scan.
const SCAN_POLL_MS = 1500;

const linkOf = (magicLogin: MagicLoginCode) =>
  magicLinkUrl(magicLogin.code, window.location.origin);

function useMinutesLeft(expiresAt: string | undefined) {
  const [now, setNow] = React.useState(() => Date.now());
  React.useEffect(() => {
    if (!expiresAt) return;
    setNow(Date.now());
    const timer = window.setInterval(() => setNow(Date.now()), 1000);
    return () => window.clearInterval(timer);
  }, [expiresAt]);
  if (!expiresAt) return null;
  return Math.max(0, Math.ceil((Date.parse(expiresAt) - now) / 60_000));
}

/** The phone section's second tab: sign in to the app without a password. */
export function MagicLoginPanel() {
  const [isQrOpen, setIsQrOpen] = React.useState(false);
  const [shown, setShown] = React.useState<MagicLoginCode | null>(null);
  const minutesLeft = useMinutesLeft(shown?.expiresAt);
  const isExpired = minutesLeft === 0;
  const qrRef = React.useRef<HTMLDivElement>(null);
  const showQrButton = React.useRef<HTMLButtonElement>(null);
  const isScanned = React.useRef(false);
  const isWaiting = isQrOpen && !!shown && !isExpired;

  useQuery({
    queryKey: sessionsKey,
    queryFn: listSessions,
    enabled: isWaiting,
    refetchInterval: SCAN_POLL_MS,
  });

  // The Devices list hands over the phone that scans the code; the code
  // leaves the dialog for its row there.
  React.useEffect(() => {
    if (!isWaiting) return;
    return waitForScan((sessionId) => {
      const qr = qrRef.current?.querySelector("svg");
      if (qr) flyQrTo(qr, sessionId);
      isScanned.current = true;
      setIsQrOpen(false);
    });
  }, [isWaiting]);

  const showQr = useMutation({
    mutationFn: createMagicLogin,
    onSuccess: (magicLogin) => {
      setShown(magicLogin);
      setIsQrOpen(true);
    },
    onError: () =>
      toast.error("Couldn’t make a QR code", { retry: () => showQr.mutate() }),
  });

  const copy = (link: string) =>
    copyText(link).then(
      () =>
        toast.success("Magic link copied. Open it on your phone to sign in."),
      () => toast.error("Couldn’t copy the magic link"),
    );

  // Each new code ends the one before, so the open QR code shares its link.
  const copyLink = useMutation({
    mutationFn: async () =>
      shown && isQrOpen && !isExpired ? shown : createMagicLogin(),
    onSuccess: (magicLogin) => {
      setShown(magicLogin);
      return copy(linkOf(magicLogin));
    },
    onError: () =>
      toast.error("Couldn’t make a magic link", {
        retry: () => copyLink.mutate(),
      }),
  });

  return (
    <>
      <Row>
        <RowText
          title="Show QR code for magic login"
          text="Once the app is installed, scan it from the app’s first screen, or open the magic link on your phone. No password needed. Each works once, within 10 minutes."
        />
        <div className="flex flex-wrap items-center gap-2">
          <Button
            ref={showQrButton}
            variant="secondary"
            onClick={() => showQr.mutate()}
            busy={showQr.isPending && "Making…"}
          >
            <QrCode aria-hidden />
            Show QR code
          </Button>
          <Button
            variant="secondary"
            onClick={() => copyLink.mutate()}
            busy={copyLink.isPending && "Copying…"}
          >
            <Link2 aria-hidden />
            Copy magic link
          </Button>
        </div>
      </Row>
      <Dialog open={isQrOpen} onOpenChange={setIsQrOpen}>
        <DialogContent
          onCloseAutoFocus={(e) => {
            if (!isScanned.current) return;
            // Back on its button without scrolling there, as the page goes
            // to the phone's row in Devices.
            isScanned.current = false;
            e.preventDefault();
            showQrButton.current?.focus({ preventScroll: true });
          }}
        >
          <DialogHeader>
            <DialogTitle>Magic login</DialogTitle>
            <DialogDescription>
              On your phone, open Anchor+ and tap <b>Scan QR code</b> on its
              first screen. It signs in to this server as you.
            </DialogDescription>
          </DialogHeader>
          <DialogBody>
            {shown && (
              <div ref={qrRef} className="relative">
                <QrImage text={linkOf(shown)} label="QR code for magic login" />
                {isExpired && (
                  <div className="absolute inset-0 grid place-items-center rounded-lg bg-card/90">
                    <Button
                      variant="secondary"
                      onClick={() => showQr.mutate()}
                      busy={showQr.isPending && "Making…"}
                    >
                      <RotateCw aria-hidden />
                      New QR code
                    </Button>
                  </div>
                )}
              </div>
            )}
            <p
              role="status"
              className="m-0 text-center text-meta text-muted-foreground"
            >
              {isExpired
                ? "This code has expired."
                : minutesLeft === 1
                  ? "Works once, for less than a minute more."
                  : `Works once, for ${minutesLeft} more minutes.`}
            </p>
            <Button
              variant="secondary"
              className="w-full"
              disabled={isExpired}
              onClick={() => copyLink.mutate()}
              busy={copyLink.isPending && "Copying…"}
            >
              <Link2 aria-hidden />
              Copy magic link
            </Button>
          </DialogBody>
        </DialogContent>
      </Dialog>
    </>
  );
}
