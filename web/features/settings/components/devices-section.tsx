"use client";

import { useMutation } from "@tanstack/react-query";
import { LogOut } from "lucide-react";
import * as React from "react";
import { Button } from "@/components/ui/button";
import { ConfirmationDialog } from "@/components/ui/confirmation-dialog";
import { toast } from "@/components/ui/toast";
import { logoutOtherDevices } from "@/features/auth/api";
import { Row, RowText, Section } from "./settings-blocks";

export function DevicesSection() {
  const [confirming, setConfirming] = React.useState(false);
  const signOutOthers = useMutation({
    mutationFn: logoutOtherDevices,
    onSuccess: () => {
      setConfirming(false);
      toast.success("Signed out of your other devices");
    },
    onError: () =>
      toast.error("Couldn’t sign out your other devices", {
        retry: () => signOutOthers.mutate(),
      }),
  });

  return (
    <Section id="devices" title="Devices">
      <Row>
        <RowText
          title="Sign out other devices"
          text="Every phone, browser and computer signed in as you, except this one."
        />
        <Button variant="secondary" onClick={() => setConfirming(true)}>
          <LogOut aria-hidden />
          Sign out others
        </Button>
      </Row>
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
