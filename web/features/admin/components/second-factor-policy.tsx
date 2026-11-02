"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { LoadFailedRow } from "@/components/ui/empty-state";
import { Skeleton } from "@/components/ui/skeleton";
import { Switch } from "@/components/ui/switch";
import { toast } from "@/components/ui/toast";
import {
  Row,
  RowText,
  SectionHeader,
} from "@/features/settings/components/settings-blocks";
import { useRetry } from "@/lib/hooks/use-retry";
import { cn } from "@/lib/utils";
import { getSecondFactorSettings, updateSecondFactorRequired } from "../api";
import { adminKeys } from "../queries";
import { cardClass } from "./admin-parts";

const SHOWN_PEOPLE = 8;

const day = (iso: string) =>
  new Date(iso).toLocaleDateString(undefined, {
    day: "numeric",
    month: "long",
    year: "numeric",
  });

/** The rule that everyone signs in with more than a password. */
export function SecondFactorPolicy() {
  const queryClient = useQueryClient();
  const settings = useQuery({
    queryKey: adminKeys.secondFactor,
    queryFn: getSecondFactorSettings,
  });
  const retry = useRetry(settings.refetch);
  const save = useMutation({
    mutationFn: updateSecondFactorRequired,
    onSuccess: (updated) => {
      queryClient.setQueryData(adminKeys.secondFactor, updated);
      toast.success(
        updated.required && updated.deadline
          ? `Everyone has until ${day(updated.deadline)}`
          : "A password alone signs people in again",
      );
    },
    onError: (_, required) =>
      toast.error("Couldn’t change the sign-in rule", {
        retry: () => save.mutate(required),
      }),
  });
  const data = settings.data;
  const passed =
    !!data?.deadline && new Date(data.deadline).getTime() <= Date.now();

  return (
    <section className="grid gap-2.5">
      <SectionHeader
        title="More than a password"
        description="Ask everyone to sign in with a passkey or an authenticator app."
      />
      {(settings.isError && !data) || retry.isRetrying ? (
        <LoadFailedRow
          message="Couldn’t load the sign-in rule."
          onRetry={retry.retry}
          isRetrying={retry.isRetrying}
        />
      ) : !data ? (
        <Skeleton className="h-20 w-full rounded-2xl" />
      ) : (
        <div
          data-slot="card"
          className={cn(cardClass, "[&>*+*]:border-border/55 [&>*+*]:border-t")}
        >
          <Row>
            <RowText
              title={
                <label htmlFor="require-second-factor">
                  Require a passkey or authenticator app
                </label>
              }
              text={
                !data.required || !data.deadline
                  ? `Everyone gets ${data.graceDays} days to add one. After that, a password alone only lets them set one up.`
                  : passed
                    ? `Since ${day(data.deadline)}, a password alone only lets people set one up.`
                    : `Everyone has until ${day(data.deadline)}. After that, a password alone only lets them set one up.`
              }
            />
            <Switch
              id="require-second-factor"
              checked={data.required}
              disabled={save.isPending}
              onCheckedChange={(required) => save.mutate(required)}
            />
          </Row>
          {data.required && (
            <Row className="block">
              {data.passwordOnly.length === 0 ? (
                <RowText
                  title="Everyone is set up"
                  text="People who sign in with single sign-on count too."
                />
              ) : (
                <div className="grid gap-2">
                  <RowText
                    title={`${data.passwordOnly.length} ${data.passwordOnly.length === 1 ? "person still signs" : "people still sign"} in with a password alone`}
                    text={
                      passed
                        ? "They’re asked to set one up when they next sign in."
                        : "They see a reminder in the app until they add one."
                    }
                  />
                  <ul className="m-0 grid list-none gap-1 p-0 text-meta">
                    {data.passwordOnly.slice(0, SHOWN_PEOPLE).map((person) => (
                      <li key={person.id} className="flex flex-wrap gap-x-2">
                        <span className="font-semibold">{person.name}</span>
                        <span className="text-muted-foreground">
                          {person.email}
                        </span>
                      </li>
                    ))}
                    {data.passwordOnly.length > SHOWN_PEOPLE && (
                      <li className="text-muted-foreground">
                        and {data.passwordOnly.length - SHOWN_PEOPLE} more
                      </li>
                    )}
                  </ul>
                </div>
              )}
            </Row>
          )}
        </div>
      )}
    </section>
  );
}
