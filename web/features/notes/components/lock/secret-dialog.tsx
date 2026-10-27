"use client";

import { useQueryClient } from "@tanstack/react-query";
import { HTTPError } from "ky";
import * as React from "react";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogBody,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Field, FormAlert } from "@/components/ui/field";
import { Input, PasswordInput } from "@/components/ui/input";
import { setNoteLockSecret } from "../../api";
import {
  checkUnlock,
  NOTE_LOCKS_KEY,
  useNoteLockSecrets,
} from "../../hooks/use-note-lock";
import { isValidPattern, isValidPin, PIN_HINT } from "../../note-lock";
import type { NoteLockSecrets } from "../../types";
import { PatternPad } from "./pattern-pad";

type SecretKind = "pin" | "pattern";

const NAME = { pin: "PIN", pattern: "pattern" } as const;

function failureText(error: unknown, kind: SecretKind) {
  const status = error instanceof HTTPError ? error.response.status : 0;
  if (status === 403)
    return kind === "pin"
      ? "That isn’t your current PIN or password."
      : "That isn’t your current pattern or password.";
  if (status === 400)
    return kind === "pin" ? `A PIN is ${PIN_HINT}` : "Join at least 4 dots.";
  return status
    ? "Couldn’t save it. Try again in a moment."
    : `Setting your ${NAME[kind]} needs a connection. Try again once you’re online.`;
}

/**
 * Sets this person's PIN or pattern, the one that opens every note locked
 * with it. Replacing one asks for it first, or the account password.
 */
export function SecretDialog({
  kind,
  open,
  onOpenChange,
  onSaved,
}: {
  kind: SecretKind;
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onSaved?: (secrets: NoteLockSecrets) => void;
}) {
  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        {open &&
          (kind === "pin" ? (
            <PinForm onClose={() => onOpenChange(false)} onSaved={onSaved} />
          ) : (
            <PatternSteps
              onClose={() => onOpenChange(false)}
              onSaved={onSaved}
            />
          ))}
      </DialogContent>
    </Dialog>
  );
}

function useSave(kind: SecretKind, onSaved?: (s: NoteLockSecrets) => void) {
  const queryClient = useQueryClient();
  const [busy, setBusy] = React.useState(false);
  const save = async (body: {
    secret: string;
    current?: string;
    password?: string;
  }) => {
    setBusy(true);
    try {
      const secrets = await setNoteLockSecret(kind, body);
      queryClient.setQueryData(NOTE_LOCKS_KEY, secrets);
      onSaved?.(secrets);
      return null;
    } catch (error) {
      return error;
    } finally {
      setBusy(false);
    }
  };
  return { save, busy };
}

/** The old one, or the account password when it's forgotten. */
function useProof() {
  const secrets = useNoteLockSecrets();
  const [forgot, setForgot] = React.useState(false);
  return {
    secrets,
    forgot,
    setForgot,
    canUsePassword: secrets.data?.hasPassword !== false,
  };
}

function PinForm({
  onClose,
  onSaved,
}: {
  onClose: () => void;
  onSaved?: (s: NoteLockSecrets) => void;
}) {
  const { secrets, forgot, setForgot, canUsePassword } = useProof();
  const replacing = !!secrets.data?.pin;
  const [current, setCurrent] = React.useState("");
  const [pin, setPin] = React.useState("");
  const [again, setAgain] = React.useState("");
  const [currentError, setCurrentError] = React.useState<string | null>(null);
  const [pinError, setPinError] = React.useState<string | null>(null);
  const [againError, setAgainError] = React.useState<string | null>(null);
  const [formError, setFormError] = React.useState<string | null>(null);
  const { save, busy } = useSave("pin", (s) => {
    onSaved?.(s);
    onClose();
  });
  const digits =
    (set: (v: string) => void) => (e: { target: { value: string } }) =>
      set(e.target.value.replace(/\D/g, ""));

  return (
    <form
      className="contents"
      onSubmit={async (e) => {
        e.preventDefault();
        setFormError(null);
        if (!isValidPin(pin)) return setPinError(`Use ${PIN_HINT}`);
        if (pin !== again) return setAgainError("The PINs don’t match.");
        const error = await save({
          secret: pin,
          ...(replacing ? (forgot ? { password: current } : { current }) : {}),
        });
        if (!error) return;
        if (error instanceof HTTPError && error.response.status === 403)
          setCurrentError(failureText(error, "pin"));
        else setFormError(failureText(error, "pin"));
      }}
    >
      <DialogHeader>
        <DialogTitle>{replacing ? "Change your PIN" : "Set a PIN"}</DialogTitle>
        <DialogDescription>
          One PIN opens every note you lock with a PIN, here and on your phone.
        </DialogDescription>
      </DialogHeader>
      <DialogBody>
        {replacing && (
          <Field
            label={forgot ? "Account password" : "Current PIN"}
            error={currentError}
            aside={
              canUsePassword && (
                <button
                  type="button"
                  className="cursor-pointer border-0 bg-transparent p-0 font-semibold text-accent-ink text-small underline decoration-current/35 underline-offset-3"
                  onClick={() => {
                    setForgot(!forgot);
                    setCurrent("");
                    setCurrentError(null);
                  }}
                >
                  {forgot ? "Use your PIN" : "Forgot?"}
                </button>
              )
            }
          >
            {forgot ? (
              <PasswordInput
                autoFocus
                autoComplete="current-password"
                value={current}
                onChange={(e) => {
                  setCurrent(e.target.value);
                  setCurrentError(null);
                }}
              />
            ) : (
              <Input
                autoFocus
                type="password"
                inputMode="numeric"
                autoComplete="off"
                maxLength={12}
                mono
                value={current}
                onChange={(e) => {
                  digits(setCurrent)(e);
                  setCurrentError(null);
                }}
              />
            )}
          </Field>
        )}
        <Field label="New PIN" help={PIN_HINT} error={pinError}>
          <Input
            autoFocus={!replacing}
            type="password"
            inputMode="numeric"
            autoComplete="off"
            maxLength={12}
            mono
            value={pin}
            onChange={(e) => {
              digits(setPin)(e);
              setPinError(null);
            }}
          />
        </Field>
        <Field label="New PIN again" error={againError}>
          <Input
            type="password"
            inputMode="numeric"
            autoComplete="off"
            maxLength={12}
            mono
            value={again}
            onChange={(e) => {
              digits(setAgain)(e);
              setAgainError(null);
            }}
          />
        </Field>
        {formError && <FormAlert>{formError}</FormAlert>}
      </DialogBody>
      <DialogFooter>
        <Button variant="quiet" onClick={onClose} disabled={busy}>
          Cancel
        </Button>
        <Button
          type="submit"
          disabled={!pin || !again || (replacing && !current)}
          busy={busy && "Saving…"}
        >
          {replacing ? "Change PIN" : "Set PIN"}
        </Button>
      </DialogFooter>
    </form>
  );
}

type PatternStep = "current" | "new" | "confirm";

function PatternSteps({
  onClose,
  onSaved,
}: {
  onClose: () => void;
  onSaved?: (s: NoteLockSecrets) => void;
}) {
  const { secrets, forgot, setForgot, canUsePassword } = useProof();
  const replacing = !!secrets.data?.pattern;
  const [step, setStep] = React.useState<PatternStep>(
    replacing ? "current" : "new",
  );
  const [current, setCurrent] = React.useState("");
  const [drawn, setDrawn] = React.useState("");
  const [error, setError] = React.useState<string | null>(null);
  const { save, busy } = useSave("pattern", (s) => {
    onSaved?.(s);
    onClose();
  });

  const finish = async (pattern: string) => {
    const failure = await save({
      secret: pattern,
      ...(replacing ? (forgot ? { password: current } : { current }) : {}),
    });
    if (!failure) return true;
    setError(failureText(failure, "pattern"));
    if (failure instanceof HTTPError && failure.response.status === 403) {
      setCurrent("");
      setDrawn("");
      setStep("current");
    }
    return false;
  };

  const prompt =
    step === "current"
      ? forgot
        ? "Enter your account password."
        : "Draw your current pattern."
      : step === "new"
        ? "Draw a new pattern, joining at least 4 dots."
        : "Draw it again to confirm.";

  return (
    <>
      <DialogHeader>
        <DialogTitle>
          {replacing ? "Change your pattern" : "Set a pattern"}
        </DialogTitle>
        <DialogDescription>
          One pattern opens every note you lock with a pattern, here and on your
          phone.
        </DialogDescription>
      </DialogHeader>
      <DialogBody className="justify-items-center">
        <p className="m-0 font-medium text-ui">{prompt}</p>
        {step === "current" && forgot ? (
          <form
            className="grid w-full gap-3"
            onSubmit={(e) => {
              e.preventDefault();
              if (!current) return;
              setError(null);
              setStep("new");
            }}
          >
            <Field label="Account password">
              <PasswordInput
                autoFocus
                autoComplete="current-password"
                value={current}
                onChange={(e) => setCurrent(e.target.value)}
              />
            </Field>
            <Button type="submit" disabled={!current}>
              Next
            </Button>
          </form>
        ) : (
          <PatternPad
            key={step}
            disabled={busy}
            label={prompt}
            onDone={async (pattern) => {
              setError(null);
              if (step === "current") {
                // Checked first, so a slip shows before drawing a new one.
                const ok = await checkUnlock(
                  "pattern",
                  pattern,
                  secrets.data,
                ).catch(() => null);
                if (ok === false) {
                  setError("That isn’t your current pattern.");
                  return false;
                }
                setCurrent(pattern);
                setStep("new");
                return true;
              }
              if (!isValidPattern(pattern)) {
                setError("Join at least 4 dots.");
                return false;
              }
              if (step === "new") {
                setDrawn(pattern);
                setStep("confirm");
                return true;
              }
              if (pattern !== drawn) {
                setError("That wasn’t the same pattern. Draw a new one.");
                setDrawn("");
                setStep("new");
                return false;
              }
              return finish(pattern);
            }}
          />
        )}
        {error && <FormAlert className="w-full">{error}</FormAlert>}
      </DialogBody>
      <DialogFooter>
        {step === "current" && canUsePassword && (
          <Button
            variant="link"
            className="mr-auto max-md:mr-0"
            onClick={() => {
              setForgot(!forgot);
              setCurrent("");
              setError(null);
            }}
          >
            {forgot ? "Use your pattern" : "Forgot?"}
          </Button>
        )}
        <Button variant="quiet" onClick={onClose} disabled={busy}>
          Cancel
        </Button>
      </DialogFooter>
    </>
  );
}
