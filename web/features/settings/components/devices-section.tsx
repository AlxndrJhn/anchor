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
import { Row, RowText, Section } from "./settings-blocks";

const sessionsKey = ["auth-sessions"];

const isPhone = (session: DeviceSession) => /Android|iOS/.test(session.device);

function sessionUse(session: DeviceSession) {
  const signedIn = `Signed in ${formatDistanceToNowStrict(new Date(session.signedInAt))} ago`;
  return session.current
    ? signedIn
    : `${signedIn}, last active ${formatDistanceToNowStrict(new Date(session.lastActiveAt))} ago`;
}

export function DevicesSection() {
  const queryClient = useQueryClient();
  const sessions = useQuery({ queryKey: sessionsKey, queryFn: listSessions });
  const retry = useRetry(sessions.refetch);
  const [confirming, setConfirming] = React.useState(false);

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
            return (
              <Row key={session.id} className="py-3 max-md:py-3">
                <Icon
                  aria-hidden
                  className="size-4.5 flex-none text-muted-foreground"
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
