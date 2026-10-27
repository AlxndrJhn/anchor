import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { pbkdf2Sync } from 'node:crypto';
import { Actor, createE2EApp, E2EApp, entryFor } from '../support';
import { bodyOf } from '../support/http';

/**
 * A lock belongs to the person, like a pin: it hides the note behind a
 * tap, PIN, pattern or fingerprint in their apps. The note isn't changed.
 */
describe('note locks', () => {
  let ctx: E2EApp;
  let owner: Actor;
  let sharee: Actor;

  beforeAll(async () => {
    ctx = await createE2EApp();
  });

  afterAll(async () => {
    await ctx.close();
  });

  beforeEach(async () => {
    await ctx.resetDb();
    owner = await ctx.registerUser('Owner');
    sharee = await ctx.registerUser('Sharee');
  });

  it('locks a note for its person only, and takes the lock off', async () => {
    const note = await owner.notes.create({ title: 'diary', content: 'x' });
    await owner.shares.grant(note.id, sharee.id, 'viewer');

    await owner.http
      .patch(`/api/notes/${note.id}/lock`)
      .send({ lock: 'biometric' })
      .expect(200, { id: note.id, lock: 'biometric' });

    expect((await owner.notes.read(note.id)).lock).toBe('biometric');
    expect((await owner.notes.list())[0].lock).toBe('biometric');
    expect((await sharee.notes.read(note.id)).lock).toBeNull();

    await owner.http
      .patch(`/api/notes/${note.id}/lock`)
      .send({ lock: null })
      .expect(200);
    expect((await owner.notes.read(note.id)).lock).toBeNull();
  });

  it('locks a selection at once', async () => {
    const a = await owner.notes.create({ title: 'a' });
    const b = await owner.notes.create({ title: 'b' });

    await owner.http
      .post('/api/notes/bulk/lock')
      .send({ noteIds: [a.id, b.id], lock: 'pin' })
      .expect(201, { count: 2 });

    const locks = (await owner.notes.list()).map((n) => n.lock);
    expect(locks).toEqual(['pin', 'pin']);
  });

  it('rejects a lock it does not know', async () => {
    const note = await owner.notes.create();
    await owner.http
      .patch(`/api/notes/${note.id}/lock`)
      .send({ lock: 'face' })
      .expect(400);
  });

  it('the sync carries the lock both ways', async () => {
    const note = await owner.notes.create({ title: 'n' });
    const before = await owner.sync.drain();

    const res = await owner.sync.push([
      { type: 'note', id: note.id, baseVersion: 1, title: 'n', lock: 'tap' },
    ]);
    expect(res.results[0].status).toBe('applied');
    expect((await owner.notes.read(note.id)).lock).toBe('tap');

    const after = await owner.sync.drain({ cursor: before.cursor });
    const entry = entryFor(after.entries, 'note', note.id);
    expect(entry.note).toMatchObject({ lock: 'tap' });

    await owner.sync.push([
      { type: 'note', id: note.id, baseVersion: 1, title: 'n', lock: null },
    ]);
    expect((await owner.notes.read(note.id)).lock).toBeNull();
  });

  it('keeps one PIN and one pattern, hashed, for the apps to check', async () => {
    const empty = await owner.http.get('/api/note-locks').expect(200);
    expect(empty.body).toEqual({
      pin: null,
      pattern: null,
      hasPassword: true,
    });

    const set = await owner.http
      .put('/api/note-locks/pin')
      .send({ secret: '2468' })
      .expect(200);
    const [scheme, iterations, salt, hash] = bodyOf<{ pin: string }>(
      set,
    ).pin.split('$');
    expect(scheme).toBe('pbkdf2-sha256');
    const derived = pbkdf2Sync(
      '2468',
      Buffer.from(salt, 'base64'),
      Number(iterations),
      32,
      'sha256',
    );
    expect(derived.toString('base64')).toBe(hash);

    const verify = (kind: string, secret: string) =>
      owner.http
        .post('/api/note-locks/verify')
        .send({ kind, secret })
        .expect(200)
        .then((r) => bodyOf<{ ok: boolean }>(r).ok);
    expect(await verify('pin', '2468')).toBe(true);
    expect(await verify('pin', '1111')).toBe(false);
    expect(await verify('pattern', '0124')).toBe(false);
    expect(await verify('password', 'wrong')).toBe(false);
  });

  it('changing a PIN takes the old one or the password', async () => {
    await owner.http.put('/api/note-locks/pin').send({ secret: '2468' });

    await owner.http
      .put('/api/note-locks/pin')
      .send({ secret: '1357' })
      .expect(403);
    await owner.http
      .put('/api/note-locks/pin')
      .send({ secret: '1357', current: '0000' })
      .expect(403);
    await owner.http
      .put('/api/note-locks/pin')
      .send({ secret: '1357', current: '2468' })
      .expect(200);
  });

  it('checks the shape of PINs and patterns', async () => {
    const put = (kind: string, secret: string) =>
      owner.http.put(`/api/note-locks/${kind}`).send({ secret });
    await put('pin', '12').expect(400);
    await put('pin', 'abcd').expect(400);
    await put('pattern', '012').expect(400);
    await put('pattern', '0120').expect(400);
    await put('pattern', '0129').expect(400);
    await put('pattern', '03678').expect(200);
    await put('fingerprint', '1234').expect(400);
  });
});
