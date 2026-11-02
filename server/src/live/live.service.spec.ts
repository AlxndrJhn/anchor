import { describe, expect, it, vi } from 'vitest';
import {
  ConflictException,
  NotFoundException,
  PayloadTooLargeException,
} from '@nestjs/common';
import type { ConfigService } from '@nestjs/config';
import { parseIceServers } from '../config/configuration';
import type { NoteAccessService } from '../notes/services/note-access.service';
import type { PrismaService } from '../prisma/prisma.service';
import type { SyncEmitterService } from '../sync/sync-emitter.service';
import type { SyncEventsService } from '../sync/sync-events.service';
import type { LiveSignalDto } from './dto/live-signal.dto';
import { LiveService, MAX_LIVE_SIGNAL_DATA_LENGTH } from './live.service';

const want: LiveSignalDto = {
  noteId: 'note-1',
  liveId: 'live-1',
  kind: 'want',
  from: { device: 'phone', tab: 't1' },
  to: { device: 'desk' },
};

function setup(recipients = ['owner', 'sharee']) {
  const access = {
    ensureNoteAccess: vi
      .fn()
      .mockResolvedValue({ hasAccess: true, state: 'active' }),
  };
  const emitter = { noteRecipients: vi.fn().mockResolvedValue(recipients) };
  const events = { signal: vi.fn() };
  const config = { get: vi.fn().mockReturnValue([{ urls: 'stun:x' }]) };
  const service = new LiveService(
    {} as PrismaService,
    access as unknown as NoteAccessService,
    emitter as unknown as SyncEmitterService,
    events as unknown as SyncEventsService,
    config as unknown as ConfigService,
  );
  return { service, access, emitter, events };
}

describe('LiveService', () => {
  it('passes the message to everyone who can open the note, naming the sender', async () => {
    const { service, events } = setup();

    await service.signal('sharee', want);

    expect(events.signal).toHaveBeenCalledTimes(2);
    expect(events.signal).toHaveBeenCalledWith('owner', {
      ...want,
      fromUser: 'sharee',
    });
    expect(events.signal).toHaveBeenCalledWith('sharee', {
      ...want,
      fromUser: 'sharee',
    });
  });

  it('sends nothing for a note the sender cannot open', async () => {
    const { service, access, events } = setup();
    access.ensureNoteAccess.mockRejectedValue(new NotFoundException());

    await expect(service.signal('stranger', want)).rejects.toThrow(
      NotFoundException,
    );
    expect(events.signal).not.toHaveBeenCalled();
  });

  it('connects nothing for a note in the trash', async () => {
    const { service, access, events } = setup();
    access.ensureNoteAccess.mockResolvedValue({
      hasAccess: true,
      state: 'trashed',
    });

    await expect(service.signal('owner', want)).rejects.toThrow(
      ConflictException,
    );
    expect(events.signal).not.toHaveBeenCalled();
  });

  it('refuses a message too large to be a connection offer', async () => {
    const { service, events } = setup();
    const data = { sdp: 'x'.repeat(MAX_LIVE_SIGNAL_DATA_LENGTH + 1) };

    await expect(
      service.signal('owner', { ...want, kind: 'offer', data }),
    ).rejects.toThrow(PayloadTooLargeException);
    expect(events.signal).not.toHaveBeenCalled();
  });

  it('gives the configured ICE servers', () => {
    expect(setup().service.iceServers()).toEqual([{ urls: 'stun:x' }]);
  });
});

describe('parseIceServers', () => {
  it('has none by default', () => {
    expect(parseIceServers(undefined)).toEqual([]);
    expect(parseIceServers('  ')).toEqual([]);
  });

  it('reads a comma-separated list of URLs', () => {
    expect(
      parseIceServers('stun:stun.example.org:3478, turn:turn.example.org'),
    ).toEqual([
      { urls: 'stun:stun.example.org:3478' },
      { urls: 'turn:turn.example.org' },
    ]);
  });

  it('reads a JSON list with logins, dropping entries without URLs', () => {
    expect(
      parseIceServers(
        '[{"urls":"turn:t.example.org","username":"u","credential":"p"},{"x":1}]',
      ),
    ).toEqual([{ urls: 'turn:t.example.org', username: 'u', credential: 'p' }]);
  });

  it('ignores JSON it cannot read', () => {
    expect(parseIceServers('[nope')).toEqual([]);
  });
});
