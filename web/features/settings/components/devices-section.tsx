"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { formatDistanceToNowStrict } from "date-fns";
import { LogOut, Monitor, Smartphone } from "lucide-react";
import * as React from "react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { ConfirmationDialog } from "@/components/ui/confirmation-dialog";
import { LoadFailedRow } from "@/components/ui/empty-state";
import { Skeleton } from "@/components/ui/skeleton";
import { toast } from "@/components/ui/toast";
import {
  listSessions,
  logoutOtherDevices,
  revokeSession,
} from "@/features/auth/api";
import type { DeviceSession } from "@/features/auth/types";
import { useRetry } from "@/lib/hooks/use-retry";
import { cn } from "@/lib/utils";
import { Row, RowText, Section } from "./settings-blocks";

const sessionsKey = ["auth-sessions"];
// Checks for a device that just signed in, such as a phone joining, while
// the page is open.
const POLL_MS = 5000;
// How long a new device's row keeps its arrival markup.
const ARRIVAL_MS = 2800;
// The streaks of light a new device arrives on: their direction in degrees
// and how far out they start, in pixels.
const STREAKS = Array.from({ length: 18 }, (_, i) => ({
  angle: i * (360 / 18) + (i % 2 ? 7 : -5),
  reach: 80 + ((i * 53) % 170),
}));

const isPhone = (session: DeviceSession) => /Android|iOS/.test(session.device);

function sessionUse(session: DeviceSession) {
  const signedIn = `Signed in ${formatDistanceToNowStrict(new Date(session.signedInAt))} ago`;
  return session.current
    ? signedIn
    : `${signedIn}, last active ${formatDistanceToNowStrict(new Date(session.lastActiveAt))} ago`;
}

export function DevicesSection() {
  const queryClient = useQueryClient();
  const sessions = useQuery({
    queryKey: sessionsKey,
    queryFn: listSessions,
    refetchInterval: POLL_MS,
  });
  const retry = useRetry(sessions.refetch);
  const [confirming, setConfirming] = React.useState(false);
  const arrived = useArrivals(sessions.data);

  const refresh = () =>
    queryClient.invalidateQueries({ queryKey: sessionsKey });

  const signOutOne = useMutation({
    mutationFn: (session: DeviceSession) => revokeSession(session.id),
    onSuccess: (_, session) => {
      void refresh();
      toast.success(`Signed out ${session.device}`);
    },
    onError: (_, session) =>
      toast.error(`Couldn’t sign out ${session.device}`, {
        retry: () => signOutOne.mutate(session),
      }),
  });
  const signOutOthers = useMutation({
    mutationFn: logoutOtherDevices,
    onSuccess: () => {
      setConfirming(false);
      void refresh();
      toast.success("Signed out of your other devices");
    },
    onError: () =>
      toast.error("Couldn’t sign out your other devices", {
        retry: () => signOutOthers.mutate(),
      }),
  });

  const others = sessions.data?.filter((session) => !session.current) ?? [];

  return (
    <Section
      id="devices"
      title="Devices"
      description="Where you’re signed in. Sign out a device you don’t use or don’t recognize."
    >
      {sessions.isError || retry.isRetrying ? (
        <Row>
          <LoadFailedRow
            className="flex-1"
            message="Couldn’t load your devices."
            onRetry={retry.retry}
            isRetrying={retry.isRetrying}
          />
        </Row>
      ) : !sessions.data ? (
        <Row className="grid gap-3" aria-busy="true">
          <Skeleton className="h-4 w-1/3" />
          <Skeleton className="h-3 w-2/3" />
        </Row>
      ) : (
        <>
          {sessions.data.map((session) => {
            const Icon = isPhone(session) ? Smartphone : Monitor;
            const isSigningOut =
              signOutOne.isPending && signOutOne.variables?.id === session.id;
            const isNew = arrived.has(session.id);
            const row = (
              <Row key={session.id} className="py-3 max-md:py-3">
                <Icon
                  aria-hidden
                  className={cn(
                    "size-4.5 flex-none text-muted-foreground",
                    isNew && "teleport-icon",
                  )}
                />
                <RowText
                  title={session.device}
                  saved={
                    session.current && <Badge tone="ok">This device</Badge>
                  }
                  text={sessionUse(session)}
                />
                {!session.current && (
                  <Button
                    variant="quiet"
                    aria-label={`Sign out ${session.device}`}
                    onClick={() => signOutOne.mutate(session)}
                    busy={isSigningOut && "Signing out…"}
                  >
                    Sign out
                  </Button>
                )}
              </Row>
            );
            return isNew ? (
              <div key={session.id} className="teleport-in">
                <TeleportFx />
                {row}
              </div>
            ) : (
              row
            );
          })}
          {others.length > 1 && (
            <Row>
              <RowText
                title="Sign out other devices"
                text="Every device above except this one."
              />
              <Button variant="secondary" onClick={() => setConfirming(true)}>
                <LogOut aria-hidden />
                Sign out others
              </Button>
            </Row>
          )}
        </>
      )}
      <ConfirmationDialog
        open={confirming}
        onOpenChange={(open) => !open && setConfirming(false)}
        title="Sign out your other devices?"
        description="Within 15 minutes they’ll be asked to sign in again. This device stays signed in."
        confirmLabel="Sign out others"
        busyLabel="Signing out…"
        variant="destructive"
        isPending={signOutOthers.isPending}
        onConfirm={() => signOutOthers.mutate()}
      />
    </Section>
  );
}

/** A device's arrival: streaks of light rush in to where its icon goes and
 * burst there, a scanline draws the row, and sparks circle the icon a while,
 * as they do round the + of Anchor+. */
function TeleportFx() {
  return (
    <div aria-hidden className="teleport-fx">
      {STREAKS.map(({ angle, reach }, i) => (
        <i
          key={angle}
          className="teleport-streak"
          style={
            {
              "--a": `${angle}deg`,
              "--d": `${reach}px`,
              "--i": i,
            } as React.CSSProperties
          }
        />
      ))}
      <i className="teleport-portal" />
      <i className="teleport-core" />
      <i className="teleport-wave" />
      <i className="teleport-wave teleport-wave-late" />
      <i className="teleport-scan" />
      <i className="teleport-orbit">
        {[0, 1, 2].map((i) => (
          <b key={i} style={{ "--i": i } as React.CSSProperties}>
            <b />
          </b>
        ))}
      </i>
    </div>
  );
}

/** The devices that turned up since the list first loaded, for a while after
 * each shows, so they can arrive with a flourish. */
function useArrivals(sessions: DeviceSession[] | undefined) {
  const seen = React.useRef<Set<string> | null>(null);
  const timers = React.useRef<number[]>([]);
  const [arrived, setArrived] = React.useState<ReadonlySet<string>>(
    () => new Set(),
  );

  React.useEffect(() => {
    if (!sessions) return;
    const ids = sessions.map((session) => session.id);
    if (!seen.current) {
      seen.current = new Set(ids);
      return;
    }
    const known = seen.current;
    const fresh = ids.filter((id) => !known.has(id));
    if (!fresh.length) return;
    for (const id of fresh) known.add(id);
    setArrived((current) => new Set([...current, ...fresh]));
    timers.current.push(
      window.setTimeout(
        () =>
          setArrived((current) => {
            const next = new Set(current);
            for (const id of fresh) next.delete(id);
            return next;
          }),
        ARRIVAL_MS,
      ),
    );
  }, [sessions]);

  React.useEffect(
    () => () => {
      for (const timer of timers.current) window.clearTimeout(timer);
    },
    [],
  );

  return arrived;
}
