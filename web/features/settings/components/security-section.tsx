"use client";

import { browserSupportsWebAuthn } from "@simplewebauthn/browser";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { formatDistanceToNowStrict } from "date-fns";
import { HTTPError } from "ky";
import {
  Copy,
  FingerprintPattern,
  KeyRound,
  Plus,
  ShieldCheck,
} from "lucide-react";
import * as React from "react";
import { Button } from "@/components/ui/button";
import { ConfirmationDialog } from "@/components/ui/confirmation-dialog";
import {
  Dialog,
  DialogBody,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { LoadFailedRow } from "@/components/ui/empty-state";
import { Field, FormAlert } from "@/components/ui/field";
import { Input } from "@/components/ui/input";
import { QrImage } from "@/components/ui/qr-image";
import { Skeleton } from "@/components/ui/skeleton";
import { Switch } from "@/components/ui/switch";
import { toast } from "@/components/ui/toast";
import {
  addPasskey,
  disableTwoStep,
  enableTwoStep,
  getSecurity,
  regenerateRecoveryCodes,
  removePasskey,
  setPasswordSignIn,
  startProviderLink,
  startTwoStep,
} from "@/features/auth/api";
import { useOidcConfig } from "@/features/auth/hooks/use-oidc";
import { useAuthStore } from "@/features/auth/store";
import type { Passkey } from "@/features/auth/types";
import { isPasskeyCancelled } from "@/features/auth/utils/sign-in-error";
import { copyText } from "@/lib/clipboard";
import { useRetry } from "@/lib/hooks/use-retry";
import { Row, RowText, Section } from "./settings-blocks";

const securityKey = ["auth-security"];

/** "Chrome on Windows", to tell passkeys apart. */
function thisDeviceName() {
  const ua = navigator.userAgent;
  const browser = /Edg\//.test(ua)
    ? "Edge"
    : /Firefox\//.test(ua)
      ? "Firefox"
      : /Chrome\//.test(ua)
        ? "Chrome"
        : /Safari\//.test(ua)
          ? "Safari"
          : "Browser";
  const os = /Android/.test(ua)
    ? "Android"
    : /iPhone|iPad/.test(ua)
      ? "iOS"
      : /Mac OS/.test(ua)
        ? "macOS"
        : /Windows/.test(ua)
          ? "Windows"
          : /Linux/.test(ua)
            ? "Linux"
            : "";
  return os ? `${browser} on ${os}` : browser;
}

const messageOf = (error: Error) =>
  error instanceof HTTPError
    ? error.message
    : "Couldn’t reach the server. Check your connection and try again.";

function passkeyUse(passkey: Passkey) {
  const added = `Added ${formatDistanceToNowStrict(new Date(passkey.createdAt))} ago`;
  return passkey.lastUsedAt
    ? `${added}, last used ${formatDistanceToNowStrict(new Date(passkey.lastUsedAt))} ago`
    : added;
}

export function SecuritySection() {
  const queryClient = useQueryClient();
  const security = useQuery({ queryKey: securityKey, queryFn: getSecurity });
  const retry = useRetry(security.refetch);
  const [canUsePasskey, setCanUsePasskey] = React.useState(true);
  React.useEffect(() => setCanUsePasskey(browserSupportsWebAuthn()), []);
  const [removing, setRemoving] = React.useState<Passkey | null>(null);
  const [twoStepDialog, setTwoStepDialog] = React.useState<
    "setup" | "disable" | "codes" | null
  >(null);

  const refresh = () =>
    queryClient.invalidateQueries({ queryKey: securityKey });

  const add = useMutation({
    mutationFn: () => addPasskey(thisDeviceName()),
    onSuccess: () => {
      void refresh();
      toast.success("Passkey added. You can sign in with it now.");
    },
    onError: (error: Error) => {
      if (isPasskeyCancelled(error)) return;
      toast.error(
        error.name === "InvalidStateError" ||
          (error.cause instanceof Error &&
            error.cause.name === "InvalidStateError")
          ? "This device already has a passkey for your account"
          : error instanceof HTTPError
            ? messageOf(error)
            : "Couldn’t add a passkey on this device",
      );
    },
  });
  const remove = useMutation({
    mutationFn: (passkey: Passkey) => removePasskey(passkey.id),
    onSuccess: () => {
      setRemoving(null);
      void refresh();
      toast.success("Passkey removed");
    },
    onError: (error: Error) => toast.error(messageOf(error)),
  });
  const passwordSignIn = useMutation({
    mutationFn: setPasswordSignIn,
    onSuccess: (status) => queryClient.setQueryData(securityKey, status),
    onError: (error: Error) => toast.error(messageOf(error)),
  });

  const oidc = useOidcConfig();
  const providerName = oidc.data?.providerName || "your provider";
  const link = useMutation({
    mutationFn: startProviderLink,
    onSuccess: (url) => {
      window.location.href = url;
    },
    onError: (error: Error) => toast.error(messageOf(error)),
  });
  // Back from the provider after connecting.
  React.useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    const connected = params.get("provider") === "connected";
    const failure = params.get("provider_error");
    if (!connected && failure === null) return;
    document.getElementById("set-security")?.scrollIntoView({ block: "start" });
    if (connected) toast.success("Connected. You can sign in with it now.");
    else toast.error(failure || "Couldn’t connect your account");
    params.delete("provider");
    params.delete("provider_error");
    const search = params.toString();
    window.history.replaceState(
      null,
      "",
      `${window.location.pathname}${search ? `?${search}` : ""}${window.location.hash}`,
    );
  }, []);

  const status = security.data;
  // Setting one up lifts the admin's reminder (or setup screen).
  const mergeUser = useAuthStore((s) => s.mergeUser);
  React.useEffect(() => {
    if (status && "secondFactor" in status)
      mergeUser({ secondFactor: status.secondFactor ?? null });
  }, [status, mergeUser]);

  return (
    <Section
      id="security"
      title="Sign-in security"
      description="Passkeys and a second step after your password."
    >
      {security.isError || retry.isRetrying ? (
        <Row>
          <LoadFailedRow
            className="flex-1"
            message="Couldn’t load how you sign in."
            onRetry={retry.retry}
            isRetrying={retry.isRetrying}
          />
        </Row>
      ) : !status ? (
        <Row className="grid gap-3" aria-busy="true">
          <Skeleton className="h-4 w-1/3" />
          <Skeleton className="h-3 w-2/3" />
        </Row>
      ) : (
        <>
          {oidc.data?.enabled && (
            <Row>
              <RowText
                title={providerName}
                text={
                  status.providerLinked
                    ? `Connected. “Continue with ${providerName}” signs you in to this account.`
                    : `Connect it to sign in to this account with “Continue with ${providerName}”, whatever email it has.`
                }
              />
              {!status.providerLinked && (
                <Button
                  variant="secondary"
                  onClick={() => link.mutate()}
                  busy={(link.isPending || link.isSuccess) && "Opening…"}
                >
                  <KeyRound aria-hidden />
                  Connect
                </Button>
              )}
            </Row>
          )}
          <Row>
            <RowText
              title="Passkeys"
              text={
                canUsePasskey
                  ? "Sign in with your fingerprint, face or screen lock instead of a password."
                  : "This browser can’t make passkeys here. They need a secure (https) address."
              }
            />
            <Button
              variant="secondary"
              disabled={!canUsePasskey}
              onClick={() => add.mutate()}
              busy={add.isPending && "Waiting for your device…"}
            >
              <Plus aria-hidden />
              Add a passkey
            </Button>
          </Row>
          {status.passkeys.map((passkey) => (
            <Row key={passkey.id} className="py-3 max-md:py-3">
              <FingerprintPattern
                aria-hidden
                className="size-4.5 flex-none text-muted-foreground"
              />
              <RowText title={passkey.name} text={passkeyUse(passkey)} />
              <Button variant="quiet" onClick={() => setRemoving(passkey)}>
                Remove
              </Button>
            </Row>
          ))}
          {status.hasPassword && (
            <Row>
              <RowText
                title="Authenticator app"
                text={
                  status.twoStep
                    ? `On. Signing in with your password also asks for a code from the app. ${status.recoveryCodesLeft} recovery code${status.recoveryCodesLeft === 1 ? "" : "s"} left.`
                    : "Ask for a code from an app like Aegis, Google Authenticator or 1Password after your password."
                }
              />
              {status.twoStep ? (
                <div className="flex flex-wrap items-center gap-2">
                  <Button
                    variant="secondary"
                    onClick={() => setTwoStepDialog("codes")}
                  >
                    New recovery codes
                  </Button>
                  <Button
                    variant="danger"
                    onClick={() => setTwoStepDialog("disable")}
                  >
                    Turn off
                  </Button>
                </div>
              ) : (
                <Button
                  variant="secondary"
                  onClick={() => setTwoStepDialog("setup")}
                >
                  <ShieldCheck aria-hidden />
                  Set up
                </Button>
              )}
            </Row>
          )}
          {status.hasPassword && (
            <Row>
              <RowText
                title={
                  <label htmlFor="password-sign-in">
                    Sign in with password
                  </label>
                }
                text={
                  status.passkeys.length === 0
                    ? "Add a passkey before you turn this off."
                    : status.passwordSignIn
                      ? "Turn off to sign in only with your passkeys. Phone sign-in by QR code still works."
                      : "Off. Only your passkeys sign you in."
                }
              />
              <Switch
                id="password-sign-in"
                checked={status.passwordSignIn}
                disabled={
                  passwordSignIn.isPending ||
                  (status.passwordSignIn && status.passkeys.length === 0)
                }
                onCheckedChange={(on) => passwordSignIn.mutate(on)}
              />
            </Row>
          )}
        </>
      )}
      <ConfirmationDialog
        open={!!removing}
        onOpenChange={(open) => !open && setRemoving(null)}
        title="Remove this passkey?"
        description={`“${removing?.name}” won’t sign you in anymore. Remove it from the device’s passkey list too.`}
        confirmLabel="Remove"
        busyLabel="Removing…"
        isPending={remove.isPending}
        onConfirm={() => removing && remove.mutate(removing)}
      />
      <TwoStepSetupDialog
        open={twoStepDialog === "setup"}
        onOpenChange={(open) => !open && setTwoStepDialog(null)}
        onDone={refresh}
      />
      <TwoStepCodeDialog
        open={twoStepDialog === "disable" || twoStepDialog === "codes"}
        mode={twoStepDialog === "codes" ? "codes" : "disable"}
        onOpenChange={(open) => !open && setTwoStepDialog(null)}
        onDone={refresh}
      />
    </Section>
  );
}

function RecoveryCodeList({ codes }: { codes: string[] }) {
  const copy = () =>
    copyText(codes.join("\n")).then(
      () => toast.success("Recovery codes copied"),
      () => toast.error("Couldn’t copy the recovery codes"),
    );
  return (
    <div className="grid gap-3">
      <ul
        aria-label="Recovery codes"
        className="m-0 grid list-none grid-cols-2 gap-x-6 gap-y-1.5 rounded-lg bg-foreground/4 p-4 font-mono text-ui"
      >
        {codes.map((code) => (
          <li key={code}>{code}</li>
        ))}
      </ul>
      <Button variant="secondary" onClick={copy}>
        <Copy aria-hidden />
        Copy codes
      </Button>
    </div>
  );
}

function TwoStepSetupDialog({
  open,
  onOpenChange,
  onDone,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onDone: () => void;
}) {
  const [code, setCode] = React.useState("");
  const [error, setError] = React.useState<string | null>(null);
  const setup = useMutation({ mutationFn: startTwoStep });
  const enable = useMutation({
    mutationFn: enableTwoStep,
    onSuccess: onDone,
    onError: (e: Error) => {
      setCode("");
      setError(
        e instanceof HTTPError && e.response.status === 403
          ? "That code isn’t right. Use the one the app shows now."
          : messageOf(e),
      );
    },
  });

  // A fresh secret each time the dialog opens.
  const { mutate: startSetup, reset: resetSetup } = setup;
  const { reset: resetEnable } = enable;
  React.useEffect(() => {
    if (!open) return;
    setCode("");
    setError(null);
    resetEnable();
    resetSetup();
    startSetup();
  }, [open, startSetup, resetSetup, resetEnable]);

  const recoveryCodes = enable.data?.recoveryCodes;

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>
            {recoveryCodes
              ? "Save your recovery codes"
              : "Set up an authenticator app"}
          </DialogTitle>
          <DialogDescription>
            {recoveryCodes
              ? "Each one signs you in once if you lose your phone. Keep them somewhere safe, like a password manager. They won’t be shown again."
              : "Scan the QR code with your authenticator app, then enter the six-digit code it shows."}
          </DialogDescription>
        </DialogHeader>
        <DialogBody>
          {recoveryCodes ? (
            <RecoveryCodeList codes={recoveryCodes} />
          ) : setup.isError ? (
            <FormAlert>{messageOf(setup.error)}</FormAlert>
          ) : !setup.data ? (
            <Skeleton className="mx-auto aspect-square w-full max-w-64 rounded-lg" />
          ) : (
            <form
              id="two-step-setup"
              className="grid gap-3.5"
              onSubmit={(e) => {
                e.preventDefault();
                setError(null);
                enable.mutate(code.trim());
              }}
            >
              <QrImage
                text={setup.data.uri}
                label="QR code for your authenticator app"
              />
              <p className="m-0 text-center text-meta text-muted-foreground">
                Can’t scan it? Enter this key:{" "}
                <code className="break-all font-mono text-foreground">
                  {setup.data.secret.replace(/(.{4})/g, "$1 ").trim()}
                </code>
              </p>
              <Field label="Code from the app" error={error}>
                <Input
                  autoFocus
                  autoComplete="one-time-code"
                  inputMode="numeric"
                  value={code}
                  onChange={(e) => {
                    setCode(e.target.value);
                    setError(null);
                  }}
                />
              </Field>
            </form>
          )}
        </DialogBody>
        <DialogFooter>
          {recoveryCodes ? (
            <Button onClick={() => onOpenChange(false)}>Done</Button>
          ) : (
            <>
              <Button variant="quiet" onClick={() => onOpenChange(false)}>
                Cancel
              </Button>
              <Button
                type="submit"
                form="two-step-setup"
                disabled={!setup.data || code.replace(/\s/g, "").length < 6}
                busy={enable.isPending && "Turning on…"}
              >
                Turn on
              </Button>
            </>
          )}
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

function TwoStepCodeDialog({
  open,
  mode,
  onOpenChange,
  onDone,
}: {
  open: boolean;
  mode: "disable" | "codes";
  onOpenChange: (open: boolean) => void;
  onDone: () => void;
}) {
  const [code, setCode] = React.useState("");
  const [error, setError] = React.useState<string | null>(null);
  const submit = useMutation({
    mutationFn: async (value: string) => {
      if (mode === "codes")
        return (await regenerateRecoveryCodes(value)).recoveryCodes;
      await disableTwoStep(value);
      return null;
    },
    onSuccess: (codes) => {
      onDone();
      if (!codes) {
        onOpenChange(false);
        toast.success("Authenticator app turned off");
      }
    },
    onError: (e: Error) => {
      setCode("");
      setError(
        e instanceof HTTPError && e.response.status === 403
          ? "That code isn’t right."
          : messageOf(e),
      );
    },
  });
  const { reset } = submit;
  React.useEffect(() => {
    if (!open) return;
    setCode("");
    setError(null);
    reset();
  }, [open, reset]);

  const newCodes = submit.data;

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>
            {newCodes
              ? "Save your new recovery codes"
              : mode === "disable"
                ? "Turn off the authenticator app?"
                : "Make new recovery codes?"}
          </DialogTitle>
          <DialogDescription>
            {newCodes
              ? "Your old recovery codes don’t work anymore. Keep these somewhere safe; they won’t be shown again."
              : mode === "disable"
                ? "Signing in with your password won’t ask for a code anymore. Enter a code from the app, or a recovery code, to confirm."
                : "Your old recovery codes stop working. Enter a code from the app to confirm."}
          </DialogDescription>
        </DialogHeader>
        <DialogBody>
          {newCodes ? (
            <RecoveryCodeList codes={newCodes} />
          ) : (
            <form
              id="two-step-code"
              onSubmit={(e) => {
                e.preventDefault();
                setError(null);
                submit.mutate(code.trim());
              }}
            >
              <Field label="Code" error={error}>
                <Input
                  autoFocus
                  autoComplete="one-time-code"
                  value={code}
                  onChange={(e) => {
                    setCode(e.target.value);
                    setError(null);
                  }}
                />
              </Field>
            </form>
          )}
        </DialogBody>
        <DialogFooter>
          {newCodes ? (
            <Button onClick={() => onOpenChange(false)}>Done</Button>
          ) : (
            <>
              <Button variant="quiet" onClick={() => onOpenChange(false)}>
                Cancel
              </Button>
              <Button
                type="submit"
                form="two-step-code"
                variant={mode === "disable" ? "danger" : "primary"}
                disabled={!code.trim()}
                busy={
                  submit.isPending &&
                  (mode === "disable" ? "Turning off…" : "Making codes…")
                }
              >
                {mode === "disable" ? "Turn off" : "Make new codes"}
              </Button>
            </>
          )}
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
