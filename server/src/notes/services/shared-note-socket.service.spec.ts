import { createServer, type Server } from 'http';
import type { AddressInfo } from 'net';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { HttpAdapterHost } from '@nestjs/core';
import { WebSocket } from 'ws';
import type { PrismaService } from '../../prisma/prisma.service';
import { SharedNoteEventsService } from '../../sync/shared-note-events.service';
import { MAX_SHARED_NOTE_SOCKETS_PER_NOTE } from '../../sync/sync.constants';
import type { NoteShareLinksService } from './note-share-links.service';
import {
  LINK_GONE_CLOSE_CODE,
  SharedNoteSocketService,
  tokenOfUpgrade,
} from './shared-note-socket.service';

const TOKEN = 'tok_EN-1';

describe('tokenOfUpgrade', () => {
  it('reads the token from the events path only', () => {
    expect(tokenOfUpgrade('/api/shared/abc_D-9/events')).toBe('abc_D-9');
    expect(tokenOfUpgrade('/api/shared/abc/events?x=1')).toBe('abc');
    expect(tokenOfUpgrade('/api/shared/abc')).toBeNull();
    expect(tokenOfUpgrade('/api/shared/a%2Fb/events')).toBeNull();
    expect(tokenOfUpgrade('/api/sync/events')).toBeNull();
    expect(tokenOfUpgrade(undefined)).toBeNull();
  });
});

describe('SharedNoteSocketService', () => {
  let server: Server;
  let url: string;
  let events: SharedNoteEventsService;
  let service: SharedNoteSocketService;
  const linkedNoteId = vi.fn();
  const open: WebSocket[] = [];

  beforeEach(async () => {
    linkedNoteId.mockImplementation((token: string) =>
      Promise.resolve(token === TOKEN ? 'note-1' : null),
    );
    // No transaction around these calls: afterCommit runs at once.
    const prisma = { afterCommit: (hook: () => void) => hook() };
    events = new SharedNoteEventsService(prisma as unknown as PrismaService);
    server = createServer();
    service = new SharedNoteSocketService(
      { httpAdapter: { getHttpServer: () => server } } as HttpAdapterHost,
      { linkedNoteId } as unknown as NoteShareLinksService,
      events,
    );
    service.onApplicationBootstrap();
    await new Promise<void>((resolve) => server.listen(0, resolve));
    url = `ws://127.0.0.1:${(server.address() as AddressInfo).port}`;
  });

  afterEach(async () => {
    for (const ws of open.splice(0)) ws.terminate();
    service.onApplicationShutdown();
    await new Promise((resolve) => server.close(resolve));
  });

  const connect = (token = TOKEN) => {
    const ws = new WebSocket(`${url}/api/shared/${token}/events`);
    // A refused socket errors too; the tests look at how it was refused.
    ws.on('error', () => {});
    open.push(ws);
    return ws;
  };
  const opened = (ws: WebSocket) =>
    new Promise<void>((resolve, reject) => {
      ws.once('open', () => resolve());
      ws.once('unexpected-response', () => reject(new Error('refused')));
    });
  const nextMessage = (ws: WebSocket) =>
    new Promise<unknown>((resolve) =>
      ws.once('message', (data) =>
        resolve(JSON.parse((data as Buffer).toString())),
      ),
    );
  const refusedWith = (ws: WebSocket) =>
    new Promise<number>((resolve) =>
      ws.once('unexpected-response', (_req, res) => resolve(res.statusCode!)),
    );

  it('tells an open page when its note changes, once the change commits', async () => {
    const ws = connect();
    await opened(ws);
    expect(service.socketCount('note-1')).toBe(1);

    const message = nextMessage(ws);
    events.scheduleChanged(['note-2', 'note-1']);

    await expect(message).resolves.toEqual({ type: 'changed' });
  });

  it("refuses a token that doesn't open a note", async () => {
    await expect(refusedWith(connect('nope'))).resolves.toBe(404);
    expect(events.listenerCount('note-1')).toBe(0);
  });

  it('closes the page for good when the link is turned off', async () => {
    const ws = connect();
    await opened(ws);
    const closed = new Promise<number>((resolve) =>
      ws.once('close', (code) => resolve(code)),
    );
    const message = nextMessage(ws);

    events.gone('note-1');

    await expect(message).resolves.toEqual({ type: 'gone' });
    await expect(closed).resolves.toBe(LINK_GONE_CLOSE_CODE);
    await vi.waitFor(() => expect(events.listenerCount('note-1')).toBe(0));
    expect(service.socketCount('note-1')).toBe(0);
  });

  it('stops listening when the page goes away', async () => {
    const ws = connect();
    await opened(ws);
    expect(events.listenerCount('note-1')).toBe(1);

    ws.close();

    await vi.waitFor(() => expect(events.listenerCount('note-1')).toBe(0));
  });

  it('turns pages away past the cap for one note', async () => {
    const sockets = Array.from(
      { length: MAX_SHARED_NOTE_SOCKETS_PER_NOTE },
      () => connect(),
    );
    await Promise.all(sockets.map(opened));

    await expect(refusedWith(connect())).resolves.toBe(503);
  });

  it('leaves other upgrade paths alone', async () => {
    const other = vi.fn();
    server.on('upgrade', (req, socket) => {
      other(req.url);
      socket.destroy();
    });
    const ws = new WebSocket(`${url}/api/other`);
    open.push(ws);
    await new Promise((resolve) => ws.once('error', resolve));

    expect(other).toHaveBeenCalledWith('/api/other');
    expect(linkedNoteId).not.toHaveBeenCalled();
  });
});
