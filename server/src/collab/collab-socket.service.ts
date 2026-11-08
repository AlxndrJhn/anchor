import type { IncomingMessage, Server } from 'http';
import type { Duplex } from 'stream';
import {
  Injectable,
  Logger,
  OnApplicationBootstrap,
  OnApplicationShutdown,
} from '@nestjs/common';
import { HttpAdapterHost } from '@nestjs/core';
import { WebSocket, WebSocketServer } from 'ws';
import { CollabService, type CollabJoin } from './collab.service';
import {
  COLLAB_CLOSE_FULL,
  COLLAB_CLOSE_GONE,
  COLLAB_CLOSE_RATE,
  COLLAB_CLOSE_UNAUTHORIZED,
  COLLAB_JOIN_TIMEOUT_MS,
  COLLAB_MAX_CONNECTION_AGE_MS,
  COLLAB_PATH,
  COLLAB_PING_INTERVAL_MS,
  COLLAB_RATE_WINDOW_MS,
  MAX_COLLAB_MESSAGE_BYTES,
  MAX_COLLAB_MESSAGES_PER_WINDOW,
} from './collab.constants';

type Joined = Exclude<Awaited<ReturnType<CollabService['join']>>, string>;

/**
 * The WebSocket for editing a note together. Browsers can't set headers on
 * one, so the first message says who's asking and for which note.
 */
@Injectable()
export class CollabSocketService
  implements OnApplicationBootstrap, OnApplicationShutdown
{
  private readonly logger = new Logger(CollabSocketService.name);
  private readonly wss = new WebSocketServer({
    noServer: true,
    maxPayload: MAX_COLLAB_MESSAGE_BYTES,
  });
  private readonly alive = new WeakSet<WebSocket>();
  private server?: Server;
  private heartbeat?: NodeJS.Timeout;

  constructor(
    private adapterHost: HttpAdapterHost,
    private collab: CollabService,
  ) {}

  onApplicationBootstrap(): void {
    this.server = this.adapterHost.httpAdapter?.getHttpServer() as
      Server | undefined;
    this.server?.on('upgrade', this.onUpgrade);
    this.heartbeat = setInterval(() => this.ping(), COLLAB_PING_INTERVAL_MS);
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

  private readonly onUpgrade = (
    req: IncomingMessage,
    socket: Duplex,
    head: Buffer,
  ): void => {
    if ((req.url ?? '').split('?')[0] !== COLLAB_PATH) {
      return;
    }
    socket.on('error', () => socket.destroy());
    this.wss.handleUpgrade(req, socket, head, (ws) => this.connected(ws));
  };

  private connected(ws: WebSocket): void {
    this.alive.add(ws);
    let joined: Joined | null = null;
    let joining = false;
    let sent = 0;
    let windowStart = Date.now();
    // Everything from one socket is handled in the order it was sent.
    let inbox: Promise<unknown> = Promise.resolve();

    const joinTimer = setTimeout(
      () => ws.close(COLLAB_CLOSE_UNAUTHORIZED, 'No join'),
      COLLAB_JOIN_TIMEOUT_MS,
    );
    const ageTimer = setTimeout(
      () => ws.close(1000, 'Reconnect'),
      COLLAB_MAX_CONNECTION_AGE_MS,
    );
    ageTimer.unref();

    const connection = {
      send: (message: object) => {
        if (ws.readyState === WebSocket.OPEN) {
          ws.send(JSON.stringify(message));
        }
      },
      close: (code: number, reason: string) => ws.close(code, reason),
    };

    const handle = async (raw: unknown) => {
      let message: Record<string, unknown>;
      try {
        message = JSON.parse((raw as Buffer).toString()) as Record<
          string,
          unknown
        >;
      } catch {
        return;
      }
      if (message === null || typeof message !== 'object') {
        return;
      }
      if (!joined) {
        if (message.t !== 'join' || joining) {
          return;
        }
        joining = true;
        const outcome = await this.collab.join(
          connection,
          message as unknown as CollabJoin,
        );
        clearTimeout(joinTimer);
        joining = false;
        if (typeof outcome === 'string') {
          ws.close(
            outcome === 'full'
              ? COLLAB_CLOSE_FULL
              : outcome === 'not-found'
                ? COLLAB_CLOSE_GONE
                : COLLAB_CLOSE_UNAUTHORIZED,
            outcome,
          );
          return;
        }
        joined = outcome;
        if (ws.readyState !== WebSocket.OPEN) {
          this.collab.leave(joined.session, joined.client);
        }
        return;
      }
      const { session, client } = joined;
      switch (message.t) {
        case 'op':
          await this.collab.receiveOp(session, client, message);
          break;
        case 'cursor':
          await this.collab.receiveCursor(session, client, message);
          break;
        case 'meta':
          await this.collab.receiveMeta(session, client, message);
          break;
      }
    };

    ws.on('message', (raw) => {
      const now = Date.now();
      if (now - windowStart > COLLAB_RATE_WINDOW_MS) {
        windowStart = now;
        sent = 0;
      }
      sent += 1;
      if (sent > MAX_COLLAB_MESSAGES_PER_WINDOW) {
        ws.close(COLLAB_CLOSE_RATE, 'Too many messages');
        return;
      }
      inbox = inbox
        .then(() => handle(raw))
        .catch((error: unknown) => {
          this.logger.warn(`A message failed: ${String(error)}`);
          ws.close(1011, 'Failed');
        });
    });
    ws.on('pong', () => this.alive.add(ws));
    ws.on('error', () => ws.terminate());
    ws.on('close', () => {
      clearTimeout(joinTimer);
      clearTimeout(ageTimer);
      if (joined) {
        this.collab.leave(joined.session, joined.client);
      }
    });
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
