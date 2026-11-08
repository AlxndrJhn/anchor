import { randomUUID } from 'crypto';
import { Injectable, Logger, OnApplicationShutdown } from '@nestjs/common';
import Delta, { type Op } from 'quill-delta';
import {
  NoteSharePermission,
  NoteState,
  UserStatus,
} from 'src/generated/prisma/enums';
import { TokenResolverService } from '../auth/token-resolver.service';
import { PrismaService } from '../prisma/prisma.service';
import { NoteRevisionsService } from '../sync/note-revisions.service';
import { SharedNoteEventsService } from '../sync/shared-note-events.service';
import {
  SyncEmitterService,
  noteEmissions,
} from '../sync/sync-emitter.service';
import {
  CollabDocument,
  InvalidCollabOp,
  parseNoteContent,
  stringifyNoteContent,
  validateOps,
} from './collab-document';
import {
  COLLAB_CLOSE_GONE,
  COLLAB_CLOSE_INVALID,
  COLLAB_IDLE_GRACE_MS,
  COLLAB_SAVE_DELAY_MS,
  COLLAB_SAVE_MAX_WAIT_MS,
  COLLAB_SAVE_RETRY_MS,
  MAX_COLLAB_CLIENTS_PER_NOTE,
} from './collab.constants';

export interface CollabConnection {
  send(message: object): void;
  close(code: number, reason: string): void;
}

export interface CollabJoin {
  noteId?: string;
  link?: string;
  jwt?: string;
  sid: string;
  epoch?: string;
  rev?: number;
}

interface Client {
  id: string;
  sid: string;
  connection: CollabConnection;
  userId: string | null;
  link: string | null;
  name: string | null;
  canEdit: boolean;
  index: number | null;
  length: number;
}

interface Saved {
  doc: Delta;
  version: number;
  title: string;
  background: string | null;
}

interface Session {
  noteId: string;
  epoch: string;
  document: CollabDocument;
  title: string;
  background: string | null;
  clients: Map<string, Client>;
  saved: Saved;
  isDirty: boolean;
  lastAuthor: string | null;
  saveTimer?: NodeJS.Timeout;
  saveDeadline?: NodeJS.Timeout;
  closeTimer?: NodeJS.Timeout;
  unsubscribe: () => void;
  queue: Promise<unknown>;
}

type JoinRefusal = 'not-found' | 'unauthorized' | 'full';

/**
 * The people editing a note right now. Each open note has one session holding
 * its text in memory, the single order of changes to it, and everyone's
 * carets. The text reaches the database shortly after each change, as any
 * other edit does, so history, sync and offline devices work as usual. Like
 * the sync events, this assumes the single-instance deployment.
 */
@Injectable()
export class CollabService implements OnApplicationShutdown {
  private readonly logger = new Logger(CollabService.name);
  private readonly sessions = new Map<string, Promise<Session>>();

  constructor(
    private prisma: PrismaService,
    private tokenResolver: TokenResolverService,
    private syncEmitter: SyncEmitterService,
    private noteRevisions: NoteRevisionsService,
    private sharedNoteEvents: SharedNoteEventsService,
  ) {}

  async onApplicationShutdown(): Promise<void> {
    const open = await Promise.allSettled(this.sessions.values());
    await Promise.all(
      open.map(async (result) => {
        if (result.status !== 'fulfilled') {
          return;
        }
        const session = result.value;
        this.stopTimers(session);
        session.unsubscribe();
        await this.enqueue(session, () => this.save(session));
      }),
    );
    this.sessions.clear();
  }

  /** The client's handle for what it sends next, or why it can't join. */
  async join(
    connection: CollabConnection,
    request: CollabJoin,
  ): Promise<{ session: Session; client: Client } | JoinRefusal> {
    const identity = await this.identify(request);
    if (identity === 'unauthorized' || identity === 'not-found') {
      return identity;
    }
    const { noteId, canEdit, userId, name } = identity;

    const session = await this.openSession(noteId);
    return this.enqueue(session, () => {
      if (session.clients.size >= MAX_COLLAB_CLIENTS_PER_NOTE) {
        return 'full' as const;
      }
      clearTimeout(session.closeTimer);
      const client: Client = {
        id: randomUUID(),
        sid: request.sid,
        connection,
        userId,
        link: request.link ?? null,
        name,
        canEdit,
        index: null,
        length: 0,
      };
      const catchup =
        request.epoch === session.epoch && request.rev !== undefined
          ? session.document.since(request.rev)
          : null;
      session.clients.set(client.id, client);
      connection.send({
        t: 'hello',
        me: client.id,
        epoch: session.epoch,
        rev: session.document.rev,
        ...(catchup ? { catchup } : { doc: session.document.doc.ops }),
        canEdit,
        title: session.title,
        background: session.background,
        version: session.saved.version,
        peers: [...session.clients.values()]
          .filter((peer) => peer !== client)
          .map((peer) => this.describe(peer, client, session)),
      });
      this.broadcast(session, client, (to) => ({
        t: 'peer',
        ...this.describe(client, to, session),
      }));
      return { session, client };
    });
  }

  leave(session: Session, client: Client): void {
    void this.enqueue(session, async () => {
      if (!session.clients.delete(client.id)) {
        return;
      }
      this.broadcast(session, null, () => ({ t: 'peerGone', id: client.id }));
      if (session.clients.size > 0) {
        return;
      }
      await this.save(session);
      // A phone that lost its signal for a moment comes back to the same
      // order of changes, and can tell which of its own already arrived.
      session.closeTimer = setTimeout(
        () => void this.closeSession(session),
        COLLAB_IDLE_GRACE_MS,
      );
      session.closeTimer.unref();
    });
  }

  receiveOp(
    session: Session,
    client: Client,
    message: { ops?: unknown; rev?: unknown; id?: unknown },
  ): Promise<void> {
    return this.enqueue(session, () => {
      if (!session.clients.has(client.id)) {
        return;
      }
      const id = message.id;
      const rev = message.rev;
      if (!client.canEdit) {
        client.connection.send({ t: 'nack', id });
        return;
      }
      try {
        if (typeof id !== 'number' || typeof rev !== 'number') {
          throw new InvalidCollabOp('A change needs its id and revision');
        }
        const ops = validateOps(message.ops);
        const entry = session.document.applyClient(ops, rev, client.sid, id);
        if ('duplicateOf' in entry) {
          client.connection.send({ t: 'ack', id, rev: entry.duplicateOf });
          return;
        }
        session.lastAuthor = client.userId;
        this.afterChange(session, client, entry.rev, entry.ops);
        client.connection.send({ t: 'ack', id, rev: entry.rev });
      } catch (error) {
        if (!(error instanceof InvalidCollabOp)) {
          throw error;
        }
        // The client's text no longer lines up: it starts over from ours.
        client.connection.close(COLLAB_CLOSE_INVALID, error.message);
      }
    });
  }

  receiveCursor(
    session: Session,
    client: Client,
    message: { index?: unknown; length?: unknown; rev?: unknown },
  ): Promise<void> {
    return this.enqueue(session, () => {
      if (!session.clients.has(client.id) || !client.canEdit) {
        return;
      }
      const { index, length, rev } = message;
      if (typeof index !== 'number' || typeof rev !== 'number') {
        client.index = null;
        client.length = 0;
      } else {
        const start = session.document.rebasePosition(index, rev, client.sid);
        const end = session.document.rebasePosition(
          index + (typeof length === 'number' ? Math.max(length, 0) : 0),
          rev,
          client.sid,
        );
        client.index = start;
        client.length = Math.max(end - start, 0);
      }
      this.broadcast(session, client, () => ({
        t: 'cursor',
        id: client.id,
        index: client.index,
        length: client.length,
        rev: session.document.rev,
      }));
    });
  }

  /** Last one wins: a title or background isn't merged. */
  receiveMeta(
    session: Session,
    client: Client,
    message: { title?: unknown; background?: unknown },
  ): Promise<void> {
    return this.enqueue(session, () => {
      if (!session.clients.has(client.id) || !client.canEdit) {
        return;
      }
      const { title, background } = message;
      const update: { title?: string; background?: string | null } = {};
      if (typeof title === 'string' && title !== session.title) {
        session.title = title;
        update.title = title;
      }
      // A link can change a note's title and text, not how it looks.
      if (
        client.link === null &&
        (typeof background === 'string' || background === null) &&
        background !== session.background
      ) {
        session.background = background;
        update.background = background;
      }
      if (Object.keys(update).length === 0) {
        return;
      }
      session.lastAuthor = client.userId;
      this.broadcast(session, client, () => ({ t: 'meta', ...update }));
      this.scheduleSave(session);
    });
  }

  private afterChange(
    session: Session,
    author: Client | null,
    rev: number,
    ops: Op[],
  ): void {
    const change = new Delta(ops);
    for (const client of session.clients.values()) {
      if (client.index === null || client === author) {
        continue;
      }
      const end = change.transformPosition(client.index + client.length);
      client.index = change.transformPosition(client.index);
      client.length = Math.max(end - client.index, 0);
    }
    this.broadcast(session, author, () => ({ t: 'op', rev, ops }));
    this.scheduleSave(session);
  }

  private broadcast(
    session: Session,
    except: Client | null,
    message: (to: Client) => object,
  ): void {
    for (const client of session.clients.values()) {
      if (client !== except) {
        client.connection.send(message(client));
      }
    }
  }

  // The link API says nothing about the owner or who the note is shared with,
  // so a link's visitors see no names, and aren't known by any themselves.
  private describe(peer: Client, to: Client, session: Session) {
    return {
      id: peer.id,
      name: to.userId === null ? (peer.userId ? 'Editor' : 'Guest') : peer.name,
      canEdit: peer.canEdit,
      index: peer.index,
      length: peer.length,
      rev: session.document.rev,
    };
  }

  private async identify(request: CollabJoin): Promise<
    | {
        noteId: string;
        canEdit: boolean;
        userId: string | null;
        name: string | null;
      }
    | 'unauthorized'
    | 'not-found'
  > {
    if (request.link) {
      const link = await this.prisma.noteShareLink.findUnique({
        where: { token: request.link },
        include: { note: { select: { state: true, isFrozen: true } } },
      });
      if (!link || link.note.state !== NoteState.active) {
        return 'not-found';
      }
      return {
        noteId: link.noteId,
        canEdit:
          link.permission === NoteSharePermission.editor && !link.note.isFrozen,
        userId: null,
        name: 'Guest',
      };
    }
    if (!request.jwt || !request.noteId) {
      return 'unauthorized';
    }
    const user = await this.tokenResolver.resolveUser(request.jwt);
    if (!user || user.status !== UserStatus.active) {
      return 'unauthorized';
    }
    const access = await this.accessOf(request.noteId, user.id, null);
    if (access === null) {
      return 'not-found';
    }
    return {
      noteId: request.noteId,
      canEdit: access,
      userId: user.id,
      name: user.name,
    };
  }

  /** Whether they can edit an open note, or null when they can't see it. */
  private async accessOf(
    noteId: string,
    userId: string | null,
    link: string | null,
  ): Promise<boolean | null> {
    const note = await this.prisma.note.findUnique({
      where: { id: noteId },
      select: {
        userId: true,
        state: true,
        isFrozen: true,
        shareLink: { select: { token: true, permission: true } },
        sharedWith: {
          where: { isDeleted: false, sharedWithUserId: userId ?? '' },
          select: { permission: true },
        },
      },
    });
    if (!note || note.state !== NoteState.active) {
      return null;
    }
    if (link !== null) {
      if (note.shareLink?.token !== link) {
        return null;
      }
      return (
        note.shareLink.permission === NoteSharePermission.editor &&
        !note.isFrozen
      );
    }
    if (note.userId === userId) {
      return !note.isFrozen;
    }
    const share = note.sharedWith[0];
    if (!share) {
      return null;
    }
    return share.permission === NoteSharePermission.editor && !note.isFrozen;
  }

  private openSession(noteId: string): Promise<Session> {
    const existing = this.sessions.get(noteId);
    if (existing) {
      return existing;
    }
    const opening = this.loadSession(noteId).catch((error) => {
      this.sessions.delete(noteId);
      throw error;
    });
    this.sessions.set(noteId, opening);
    return opening;
  }

  private async loadSession(noteId: string): Promise<Session> {
    const note = await this.prisma.note.findUniqueOrThrow({
      where: { id: noteId },
    });
    const doc = parseNoteContent(note.content);
    const session: Session = {
      noteId,
      epoch: randomUUID(),
      document: new CollabDocument(doc),
      title: note.title,
      background: note.background,
      clients: new Map(),
      saved: {
        doc,
        version: note.version,
        title: note.title,
        background: note.background,
      },
      isDirty: false,
      lastAuthor: null,
      queue: Promise.resolve(),
      unsubscribe: () => {},
    };
    session.unsubscribe = this.sharedNoteEvents.subscribe(noteId, () => {
      void this.enqueue(session, () => this.reconcile(session));
    });
    return session;
  }

  private async closeSession(session: Session): Promise<void> {
    await this.enqueue(session, async () => {
      if (session.clients.size > 0) {
        return;
      }
      this.stopTimers(session);
      await this.save(session);
      if (session.isDirty) {
        // Not saved: the text is kept until it can be.
        session.closeTimer = setTimeout(
          () => void this.closeSession(session),
          COLLAB_SAVE_RETRY_MS,
        );
        session.closeTimer.unref();
        return;
      }
      session.unsubscribe();
      this.sessions.delete(session.noteId);
    });
  }

  private scheduleSave(session: Session): void {
    session.isDirty = true;
    clearTimeout(session.saveTimer);
    const fire = () => void this.enqueue(session, () => this.save(session));
    session.saveTimer = setTimeout(fire, COLLAB_SAVE_DELAY_MS);
    session.saveTimer.unref();
    if (!session.saveDeadline) {
      session.saveDeadline = setTimeout(fire, COLLAB_SAVE_MAX_WAIT_MS);
      session.saveDeadline.unref();
    }
  }

  private stopTimers(session: Session): void {
    clearTimeout(session.saveTimer);
    clearTimeout(session.saveDeadline);
    clearTimeout(session.closeTimer);
    session.saveTimer = undefined;
    session.saveDeadline = undefined;
  }

  // Always inside the session's queue. A write the session didn't make has
  // moved the version: it's merged in first, and this saves on the next turn.
  private async save(session: Session): Promise<void> {
    clearTimeout(session.saveTimer);
    clearTimeout(session.saveDeadline);
    session.saveTimer = undefined;
    session.saveDeadline = undefined;
    if (!session.isDirty) {
      return;
    }
    const doc = session.document.doc;
    const title = session.title;
    const background = session.background;
    const { noteId } = session;
    const expected = session.saved.version;
    const author = session.lastAuthor;

    let outcome: 'moved' | 'closed' | number;
    try {
      outcome = await this.prisma.$transaction(async (tx) => {
        const prior = await tx.note.findUnique({ where: { id: noteId } });
        if (!prior || prior.state !== NoteState.active || prior.isFrozen) {
          return 'closed' as const;
        }
        if (prior.version !== expected) {
          return 'moved' as const;
        }
        const updated = await tx.note.updateMany({
          where: { id: noteId, version: expected },
          data: {
            content: stringifyNoteContent(doc),
            title,
            background,
            version: { increment: 1 },
          },
        });
        if (updated.count !== 1) {
          return 'moved' as const;
        }
        await this.noteRevisions.recordEdit(tx, prior, author);
        const recipients = await this.syncEmitter.noteRecipients(tx, noteId);
        await this.syncEmitter.emit(tx, noteEmissions(recipients, noteId));
        return expected + 1;
      });
    } catch (error) {
      this.logger.warn(`Couldn't save note ${noteId}: ${String(error)}`);
      this.retrySave(session);
      return;
    }

    if (outcome === 'closed') {
      // Trashed or frozen while being edited: the reconcile tells everyone.
      session.isDirty = false;
      return;
    }
    if (outcome === 'moved') {
      await this.reconcile(session);
      this.retrySave(session);
      return;
    }
    session.saved = { doc, version: outcome, title, background };
    // Changes made while saving come after what was saved.
    session.isDirty =
      session.document.doc !== doc ||
      session.title !== title ||
      session.background !== background;
    if (session.isDirty) {
      this.scheduleSave(session);
    }
    this.broadcast(session, null, () => ({ t: 'saved', version: outcome }));
  }

  private retrySave(session: Session): void {
    session.isDirty = true;
    clearTimeout(session.saveTimer);
    session.saveTimer = setTimeout(
      () => void this.enqueue(session, () => this.save(session)),
      COLLAB_SAVE_RETRY_MS,
    );
    session.saveTimer.unref();
  }

  // Runs after anything changed the note, the session's own saves included:
  // merges in writes from outside, and applies changes to who may do what.
  private async reconcile(session: Session): Promise<void> {
    const note = await this.prisma.note.findUnique({
      where: { id: session.noteId },
    });
    if (!note || note.state !== NoteState.active) {
      for (const client of session.clients.values()) {
        client.connection.close(COLLAB_CLOSE_GONE, 'Note is gone');
      }
      session.clients.clear();
      session.isDirty = false;
      void this.closeSession(session);
      return;
    }

    if (note.version !== session.saved.version) {
      this.mergeOutside(session, note);
    }

    this.broadcast(session, null, () => ({ t: 'changed' }));

    for (const client of [...session.clients.values()]) {
      const access = await this.accessOf(
        session.noteId,
        client.userId,
        client.link,
      );
      if (access === null) {
        session.clients.delete(client.id);
        client.connection.close(COLLAB_CLOSE_GONE, 'No longer shared');
        this.broadcast(session, null, () => ({
          t: 'peerGone',
          id: client.id,
        }));
      } else if (access !== client.canEdit) {
        client.canEdit = access;
        client.connection.send({ t: 'meta', canEdit: access });
      }
    }
  }

  private mergeOutside(
    session: Session,
    note: {
      content: string | null;
      title: string;
      background: string | null;
      version: number;
    },
  ): void {
    const { saved } = session;
    const outside = saved.doc.diff(parseNoteContent(note.content));
    // Three-way: only what they changed since our last save, over what we've
    // changed since then.
    const unsaved = saved.doc.diff(session.document.doc);
    const entry = session.document.applyServer(
      unsaved.transform(outside, true),
    );
    if (entry) {
      this.afterChange(session, null, entry.rev, entry.ops);
    }
    const update: { title?: string; background?: string | null } = {};
    if (note.title !== saved.title && session.title === saved.title) {
      session.title = note.title;
      update.title = note.title;
    }
    if (
      note.background !== saved.background &&
      session.background === saved.background
    ) {
      session.background = note.background;
      update.background = note.background;
    }
    if (Object.keys(update).length > 0) {
      this.broadcast(session, null, () => ({ t: 'meta', ...update }));
    }
    session.saved = {
      doc: parseNoteContent(note.content),
      version: note.version,
      title: note.title,
      background: note.background,
    };
    session.isDirty =
      session.document.doc.diff(session.saved.doc).ops.length > 0 ||
      session.title !== session.saved.title ||
      session.background !== session.saved.background;
    if (session.isDirty) {
      this.scheduleSave(session);
    } else {
      clearTimeout(session.saveTimer);
      clearTimeout(session.saveDeadline);
      session.saveTimer = undefined;
      session.saveDeadline = undefined;
    }
    this.broadcast(session, null, () => ({
      t: 'saved',
      version: note.version,
    }));
  }

  // One thing at a time per note: changes, saves and merges see the same text.
  private enqueue<T>(session: Session, task: () => T | Promise<T>): Promise<T> {
    const run = session.queue.then(task, task);
    session.queue = run.catch((error) => {
      this.logger.error(`Collab task failed: ${String(error)}`);
    });
    return run;
  }
}
