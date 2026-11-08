"use client";

import { useQuery, useQueryClient } from "@tanstack/react-query";
import { HTTPError } from "ky";
import {
  CircleAlert,
  Download,
  Eye,
  FileText,
  LoaderCircle,
  Pencil,
  RotateCw,
  Snowflake,
} from "lucide-react";
import { useParams } from "next/navigation";
import { useEffect, useMemo, useRef, useState } from "react";
import { Brand } from "@/components/layout/brand";
import { ErrorScreen } from "@/components/layout/error-screen";
import { Button } from "@/components/ui/button";
import { toast } from "@/components/ui/toast";
import {
  fetchAttachmentBlob,
  getSharedNote,
  setAttachmentLink,
  updateSharedNote,
} from "@/features/notes/api";
import { RichTextEditor } from "@/features/notes/components/editor";
import { EditorSkeleton } from "@/features/notes/components/note-editor/editor-states";
import { useAttachmentBlob } from "@/features/notes/hooks/use-attachment-blob";
import { inlineImageIds } from "@/features/notes/inline-images";
import { connectSharedNoteEvents } from "@/features/notes/shared-note-events";
import type { SharedNote } from "@/features/notes/types";
import { useDocumentTitle } from "@/lib/hooks/use-document-title";
import { isServerless } from "@/lib/local-backend/mode";
import { cn } from "@/lib/utils";

const SAVE_DELAY_MS = 800;
// Others' changes arrive over a WebSocket the moment they're saved; without
// one (a proxy that doesn't pass it on, say), the page polls instead.
const REFRESH_MS = 15_000;

type SaveState = "saved" | "saving" | "unsaved" | "failed";

const statusOf = (error: unknown) =>
  error instanceof HTTPError ? error.response.status : null;

/** A note opened by its share link: no account, no sidebar. */
export default function SharedNotePage() {
  const { token } = useParams<{ token: string }>();
  const queryClient = useQueryClient();
  const [live, setLive] = useState(false);

  // The note's pictures and files come through the link too.
  useEffect(() => {
    setAttachmentLink(token);
    return () => setAttachmentLink(null);
  }, [token]);

  useEffect(() => {
    if (isServerless) return;
    const events = connectSharedNoteEvents(token, {
      onChange: () =>
        void queryClient.invalidateQueries({
          queryKey: ["shared-note", token],
        }),
      onConnectedChange: setLive,
    });
    return () => events.close();
  }, [token, queryClient]);

  const query = useQuery({
    queryKey: ["shared-note", token],
    queryFn: () => getSharedNote(token),
    refetchInterval: live ? false : REFRESH_MS,
    refetchOnWindowFocus: true,
  });
  useDocumentTitle(
    query.data
      ? query.data.title?.trim() || "Shared note"
      : query.isError
        ? "Note not available"
        : "Shared note",
  );

  if (query.isPending) return <EditorSkeleton />;
  // Also once it was open: the link was turned off or the note trashed.
  if (statusOf(query.error) === 404) return <LinkGone />;
  if (query.isError && !query.data) {
    return (
      <Screen>
        <ErrorScreen
          illustration="broken"
          title="Couldn’t load this note"
          text="Check your connection, then try again."
          actions={
            <Button onClick={() => void query.refetch()}>
              <RotateCw aria-hidden />
              Try again
            </Button>
          }
        />
      </Screen>
    );
  }
  return <SharedNoteEditor token={token} note={query.data} />;
}

function SharedNoteEditor({
  token,
  note,
}: {
  token: string;
  note: SharedNote;
}) {
  const queryClient = useQueryClient();
  const [title, setTitle] = useState(note.title);
  const [content, setContent] = useState(note.content ?? "");
  const [saveState, setSaveState] = useState<SaveState>("saved");
  const [gone, setGone] = useState(false);
  // The version edits are based on, and what was last saved or loaded.
  const base = useRef(note);
  const draft = useRef({ title: note.title, content: note.content ?? "" });
  const timer = useRef<number>(undefined);
  const inFlight = useRef(false);
  const queued = useRef(false);

  const adopt = (next: SharedNote) => {
    base.current = next;
    draft.current = { title: next.title, content: next.content ?? "" };
    setTitle(next.title);
    setContent(next.content ?? "");
    queryClient.setQueryData(["shared-note", token], next);
  };

  // Others' edits show while this page has none of its own waiting.
  // biome-ignore lint/correctness/useExhaustiveDependencies: only a newer copy from the server.
  useEffect(() => {
    if (note.version === base.current.version) {
      base.current = note;
      return;
    }
    if (saveState !== "saved" || inFlight.current) return;
    adopt(note);
  }, [note]);

  const save = async () => {
    if (inFlight.current) {
      queued.current = true;
      return;
    }
    const sent = draft.current;
    const prior = base.current;
    if (sent.title === prior.title && sent.content === (prior.content ?? "")) {
      setSaveState("saved");
      return;
    }
    inFlight.current = true;
    setSaveState("saving");
    try {
      const saved = await updateSharedNote(token, {
        ...(sent.title !== prior.title ? { title: sent.title } : {}),
        ...(sent.content !== (prior.content ?? "")
          ? { content: sent.content }
          : {}),
        baseVersion: prior.version,
      });
      base.current = saved;
      queryClient.setQueryData(["shared-note", token], saved);
      const changedSince = draft.current !== sent;
      setSaveState(changedSince ? "unsaved" : "saved");
      if (changedSince) queued.current = true;
    } catch (error) {
      const status = statusOf(error);
      if (status === 409 && error instanceof HTTPError) {
        const { serverNote } = (error.data ?? {}) as {
          serverNote?: SharedNote;
        };
        if (serverNote) adopt(serverNote);
        setSaveState("saved");
        toast.error(
          "Someone else changed this note at the same time; showing their version",
        );
      } else if (status === 404) {
        setGone(true);
      } else if (status === 403) {
        // The link was made view-only, or the note frozen.
        setSaveState("saved");
        await queryClient.refetchQueries({ queryKey: ["shared-note", token] });
        const now = queryClient.getQueryData<SharedNote>([
          "shared-note",
          token,
        ]);
        if (now) adopt(now);
        toast.error("This link can no longer change the note");
      } else {
        setSaveState("failed");
      }
    } finally {
      inFlight.current = false;
      if (queued.current) {
        queued.current = false;
        void save();
      }
    }
  };

  const edit = (next: { title?: string; content?: string }) => {
    draft.current = { ...draft.current, ...next };
    if (next.title !== undefined) setTitle(next.title);
    if (next.content !== undefined) setContent(next.content);
    setSaveState("unsaved");
    window.clearTimeout(timer.current);
    timer.current = window.setTimeout(() => void save(), SAVE_DELAY_MS);
  };

  // Leaving with edits not yet saved asks first.
  useEffect(() => {
    if (saveState === "saved") return;
    const warn = (e: BeforeUnloadEvent) => e.preventDefault();
    window.addEventListener("beforeunload", warn);
    return () => window.removeEventListener("beforeunload", warn);
  }, [saveState]);

  useEffect(() => () => window.clearTimeout(timer.current), []);

  const inText = useMemo(() => inlineImageIds(content), [content]);
  const files = note.attachments.filter((a) => !inText.has(a.id));

  if (gone) return <LinkGone />;

  const canEdit = note.canEdit;
  return (
    <div className="pg-editor">
      <article
        className={cn("note ed", !canEdit && "ro")}
        data-note={note.background ?? ""}
        aria-label="Note"
      >
        <div className="ed-scroll scrollbar-slim">
          <header className="ed-head">
            <Brand href="/" />
            <div className="flex items-center gap-3 text-meta text-note-muted [&_svg]:size-3.75">
              {canEdit && <SaveStatus state={saveState} onRetry={save} />}
              <span className="inline-flex items-center gap-1.5 rounded-pill bg-note-surface px-2.5 py-1">
                {note.isFrozen ? (
                  <Snowflake aria-hidden />
                ) : canEdit ? (
                  <Pencil aria-hidden />
                ) : (
                  <Eye aria-hidden />
                )}
                {note.isFrozen ? "Frozen" : canEdit ? "Can edit" : "View only"}
              </span>
            </div>
          </header>
          <div className="note-in">
            {canEdit ? (
              <textarea
                className="n-title"
                rows={1}
                value={title}
                aria-label="Title"
                placeholder="Title"
                spellCheck={false}
                onChange={(e) =>
                  edit({ title: e.target.value.replace(/[\r\n]+/g, " ") })
                }
              />
            ) : (
              <h1 className="n-title">{title || "Untitled"}</h1>
            )}
            {files.length > 0 && <SharedFiles token={token} files={files} />}
            <div className={cn("ed-body", !canEdit && "mt-4.5")}>
              <RichTextEditor
                value={content}
                onChange={(next) => edit({ content: next })}
                readOnly={!canEdit}
                noteId={token}
              />
            </div>
          </div>
        </div>
      </article>
    </div>
  );
}

function SaveStatus({
  state,
  onRetry,
}: {
  state: SaveState;
  onRetry: () => void;
}) {
  if (state === "failed")
    return (
      <button
        type="button"
        className="inline-flex cursor-pointer items-center gap-1.5 border-0 bg-transparent p-0 text-late"
        onClick={onRetry}
      >
        <CircleAlert aria-hidden />
        Couldn’t save · Try again
      </button>
    );
  return (
    <span role="status" className="inline-flex items-center gap-1.5">
      {state === "saving" && (
        <LoaderCircle aria-hidden className="animate-spin" />
      )}
      {state === "saved" ? "Saved" : state === "saving" ? "Saving…" : "Edited"}
    </span>
  );
}

function SharedFiles({
  token,
  files,
}: {
  token: string;
  files: SharedNote["attachments"];
}) {
  return (
    <div className="mb-2 flex flex-wrap gap-2">
      {files.map((file) =>
        file.type === "image" ? (
          <SharedPicture key={file.id} token={token} file={file} />
        ) : file.type === "audio" ? (
          <SharedAudio key={file.id} token={token} file={file} />
        ) : (
          <SharedFile key={file.id} token={token} file={file} />
        ),
      )}
    </div>
  );
}

type SharedAttachment = SharedNote["attachments"][number];

function SharedPicture({
  token,
  file,
}: {
  token: string;
  file: SharedAttachment;
}) {
  const { blobUrl } = useAttachmentBlob(token, file.id);
  return (
    <a
      href={blobUrl ?? undefined}
      target="_blank"
      rel="noreferrer"
      className="block size-32 overflow-hidden rounded-lg bg-note-surface"
    >
      {blobUrl && (
        <img
          src={blobUrl}
          alt={file.originalFilename}
          className="size-full object-cover"
        />
      )}
    </a>
  );
}

function SharedAudio({
  token,
  file,
}: {
  token: string;
  file: SharedAttachment;
}) {
  const { blobUrl } = useAttachmentBlob(token, file.id);
  return (
    <audio
      controls
      src={blobUrl ?? undefined}
      aria-label={file.originalFilename}
      className="h-10 max-w-full"
    />
  );
}

function SharedFile({
  token,
  file,
}: {
  token: string;
  file: SharedAttachment;
}) {
  const [busy, setBusy] = useState(false);
  return (
    <Button
      variant="secondary"
      disabled={busy}
      onClick={async () => {
        setBusy(true);
        try {
          const blob = await fetchAttachmentBlob(token, file.id);
          const url = URL.createObjectURL(blob);
          const a = document.createElement("a");
          a.href = url;
          a.download = file.originalFilename;
          a.click();
          window.setTimeout(() => URL.revokeObjectURL(url), 10_000);
        } catch {
          toast.error(`Couldn’t download ${file.originalFilename}`);
        } finally {
          setBusy(false);
        }
      }}
    >
      {busy ? (
        <LoaderCircle aria-hidden className="animate-spin" />
      ) : (
        <FileText aria-hidden />
      )}
      <span className="max-w-60 truncate">{file.originalFilename}</span>
      <Download aria-hidden />
    </Button>
  );
}

function Screen({ children }: { children: React.ReactNode }) {
  return (
    <div className="flex min-h-dvh flex-col">
      <header className="flex p-4">
        <Brand href="/" />
      </header>
      <main className="flex flex-1 items-center justify-center">
        {children}
      </main>
    </div>
  );
}

function LinkGone() {
  return (
    <Screen>
      <ErrorScreen
        illustration="note"
        title="This link doesn’t open a note"
        text="Its owner may have turned the link off, or moved the note to the trash."
        actions={null}
      />
    </Screen>
  );
}
