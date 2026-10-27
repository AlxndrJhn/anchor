"use client";

import { Grid3x3, RectangleEllipsis } from "lucide-react";
import * as React from "react";
import { Button } from "@/components/ui/button";
import { LoadFailedRow } from "@/components/ui/empty-state";
import { Skeleton } from "@/components/ui/skeleton";
import { toast } from "@/components/ui/toast";
import { SecretDialog } from "@/features/notes/components/lock/secret-dialog";
import { useNoteLockSecrets } from "@/features/notes/hooks/use-note-lock";
import { useRetry } from "@/lib/hooks/use-retry";
import { Row, RowText, Section } from "./settings-blocks";

/** The one PIN and one pattern that open the notes locked with them. */
export function NoteLocksSection() {
  const secrets = useNoteLockSecrets();
  const retry = useRetry(secrets.refetch);
  const [editing, setEditing] = React.useState<"pin" | "pattern" | null>(null);
  const rows = [
    {
      kind: "pin",
      name: "PIN",
      lower: "PIN",
      icon: <RectangleEllipsis aria-hidden />,
      isSet: !!secrets.data?.pin,
    },
    {
      kind: "pattern",
      name: "Pattern",
      lower: "pattern",
      icon: <Grid3x3 aria-hidden />,
      isSet: !!secrets.data?.pattern,
    },
  ] as const;
  return (
    <Section
      id="locks"
      title="Note locks"
      description="One PIN and one pattern open every note you lock with them, here and on your phone."
    >
      {secrets.isError && !secrets.data ? (
        <Row>
          <LoadFailedRow
            className="flex-1"
            message="Couldn’t load your note locks."
            onRetry={retry.retry}
            isRetrying={retry.isRetrying}
          />
        </Row>
      ) : secrets.isLoading ? (
        <Row aria-busy="true">
          <Skeleton className="h-4 w-1/2" />
        </Row>
      ) : (
        rows.map((row) => (
          <Row key={row.kind}>
            <RowText
              title={row.name}
              text={
                row.isSet
                  ? `Set. Changing it asks for the current ${row.lower} or your password.`
                  : `Not set yet. You can also set it the first time you lock a note with a ${row.lower}.`
              }
            />
            <Button variant="secondary" onClick={() => setEditing(row.kind)}>
              {row.icon}
              {row.isSet ? `Change ${row.lower}` : `Set ${row.lower}`}
            </Button>
          </Row>
        ))
      )}
      {editing && (
        <SecretDialog
          kind={editing}
          open
          onOpenChange={(open) => !open && setEditing(null)}
          onSaved={() =>
            toast.success(editing === "pin" ? "PIN saved" : "Pattern saved")
          }
        />
      )}
    </Section>
  );
}
