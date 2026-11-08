import { STATUS_CODES, type IncomingMessage, type Server } from 'http';
import type { Duplex } from 'stream';
import {
  Injectable,
  Logger,
  OnApplicationBootstrap,
  OnApplicationShutdown,
} from '@nestjs/common';
import { HttpAdapterHost } from '@nestjs/core';
import { WebSocket, WebSocketServer } from 'ws';
import {
  SharedNoteEventsService,
  type SharedNoteEvent,
} from '../../sync/shared-note-events.service';
import {
  MAX_SHARED_NOTE_SOCKETS_PER_NOTE,
  SHARED_NOTE_SOCKET_PING_INTERVAL_MS,
} from '../../sync/sync.constants';
import { NoteShareLinksService } from './note-share-links.service';

// wss://…/api/shared/<token>/events; tokens are base64url.
const PATH = /^\/api\/shared\/([A-Za-z0-9_-]{1,128})\/events$/;

/** Close code for a link that was turned off: the page stops reconnecting. */
export const LINK_GONE_CLOSE_CODE = 4404;

export const tokenOfUpgrade = (url: string | undefined): string | null => {
  const path = (url ?? '').split('?')[0];
  return PATH.exec(path)?.[1] ?? null;
};

/**
 * A WebSocket for each page open on a note's share link, which says when the
 * note changed so the page loads it again at once. It carries no note
 * content: the page loads that through the link as before, so what a link
 * shows is decided in one place. Pages that can't connect keep polling.
 */
@Injectable()
export class SharedNoteSocketService
  implements OnApplicationBootstrap, OnApplicationShutdown
{
  private readonly logger = new Logger(SharedNoteSocketService.name);
  // Nothing is read from the page: a tiny limit keeps it that way.
  private readonly wss = new WebSocketServer({
    noServer: true,
    maxPayload: 1024,
  });
  private readonly byNote = new Map<string, Set<WebSocket>>();
  private readonly alive = new WeakSet<WebSocket>();
  private server?: Server;
  private heartbeat?: NodeJS.Timeout;

  constructor(
    private adapterHost: HttpAdapterHost,
    private links: NoteShareLinksService,
    private events: SharedNoteEventsService,
  ) {}

  onApplicationBootstrap(): void {
    this.server = this.adapterHost.httpAdapter?.getHttpServer() as
      Server | undefined;
    this.server?.on('upgrade', this.onUpgrade);
    this.heartbeat = setInterval(
      () => this.ping(),
      SHARED_NOTE_SOCKET_PING_INTERVAL_MS,
    );
    this.heartbeat.unref();
  }

  onApplicationShutdown(): void {
    this.server?.off('upgrade', this.onUpgrade);
    clearInterval(this.heartbeat);
    for (const ws of this.wss.clients) {
      ws.terminate();
    }
    this.wss.close();
  }

  socketCount(noteId: string): number {
    return this.byNote.get(noteId)?.size ?? 0;
  }

  private readonly onUpgrade = (
    req: IncomingMessage,
    socket: Duplex,
    head: Buffer,
  ): void => {
    const token = tokenOfUpgrade(req.url);
    // Not ours: left to any other upgrade handler.
    if (!token) {
      return;
    }
    void this.upgrade(req, socket, head, token);
  };

  private async upgrade(
    req: IncomingMessage,
    socket: Duplex,
    head: Buffer,
    token: string,
  ): Promise<void> {
    socket.on('error', () => socket.destroy());
    let noteId: string | null;
    try {
      noteId = await this.links.linkedNoteId(token);
    } catch (error) {
      this.logger.warn(`Couldn't check a share link: ${String(error)}`);
      return refuse(socket, 503);
    }
    if (!noteId) {
      return refuse(socket, 404);
    }
    if (this.socketCount(noteId) >= MAX_SHARED_NOTE_SOCKETS_PER_NOTE) {
      return refuse(socket, 503);
    }
    const id = noteId;
    this.wss.handleUpgrade(req, socket, head, (ws) => this.connected(ws, id));
  }

  private connected(ws: WebSocket, noteId: string): void {
    let set = this.byNote.get(noteId);
    if (!set) {
      set = new Set();
      this.byNote.set(noteId, set);
    }
    set.add(ws);
    this.alive.add(ws);

    const unsubscribe = this.events.subscribe(noteId, (event) =>
      this.tell(ws, event),
    );
    ws.on('pong', () => this.alive.add(ws));
    ws.on('error', () => ws.terminate());
    ws.on('close', () => {
      unsubscribe();
      const current = this.byNote.get(noteId);
      current?.delete(ws);
      if (current?.size === 0) {
        this.byNote.delete(noteId);
      }
    });
  }

  private tell(ws: WebSocket, event: SharedNoteEvent): void {
    if (ws.readyState !== WebSocket.OPEN) {
      return;
    }
    ws.send(JSON.stringify({ type: event }));
    if (event === 'gone') {
      ws.close(LINK_GONE_CLOSE_CODE, 'Link turned off');
    }
  }

  // A socket that didn't answer the last ping is gone.
  private ping(): void {
    for (const ws of this.wss.clients) {
      if (!this.alive.has(ws)) {
        ws.terminate();
        continue;
      }
      this.alive.delete(ws);
      ws.ping();
    }
  }
}

function refuse(socket: Duplex, status: number): void {
  if (socket.writable) {
    socket.write(
      `HTTP/1.1 ${status} ${STATUS_CODES[status]}\r\n` +
        'Connection: close\r\nContent-Length: 0\r\n\r\n',
    );
  }
  socket.destroy();
}
