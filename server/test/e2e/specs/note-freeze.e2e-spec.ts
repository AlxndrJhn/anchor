import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { Actor, createE2EApp, E2EApp, entryFor } from '../support';

/**
 * A frozen note can't be changed, trashed or deleted, by its owner or anyone
 * it's shared with, until the owner unfreezes it.
 */
describe('frozen notes', () => {
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

  const freeze = (actor: Actor, id: string, isFrozen = true) =>
    actor.http.patch(`/api/notes/${id}/freeze`).send({ isFrozen });

  it('refuses edits, trash and delete until unfrozen', async () => {
    const note = await owner.notes.create({ title: 'deed', content: 'x' });
    expect(note.isFrozen).toBe(false);

    const frozen = await freeze(owner, note.id).expect(200);
    expect(frozen.body).toMatchObject({ isFrozen: true, version: 2 });

    await owner.http
      .patch(`/api/notes/${note.id}`)
      .send({ content: 'y' })
      .expect(403);
    await owner.http
      .patch(`/api/notes/${note.id}`)
      .send({ background: '#f00' })
      .expect(403);
    await owner.http.delete(`/api/notes/${note.id}`).expect(403);
    await owner.http.delete(`/api/notes/${note.id}/permanent`).expect(403);
    await owner.http
      .post(`/api/notes/${note.id}/attachments`)
      .attach('file', Buffer.from('hi'), 'a.txt')
      .expect(403);
    expect(await owner.notes.bulkTrash([note.id])).toEqual({ count: 0 });

    const read = await owner.notes.read(note.id);
    expect(read).toMatchObject({ content: 'x', state: 'active' });

    // What is the person's own still changes.
    await owner.http
      .patch(`/api/notes/${note.id}`)
      .send({ isPinned: true })
      .expect(200);

    await freeze(owner, note.id, false).expect(200);
    await owner.notes.update(note.id, { content: 'y' });
    await owner.notes.trash(note.id);
  });

  it('only the owner freezes, and sharees cannot edit it either', async () => {
    const note = await owner.notes.create({ title: 'n' });
    await owner.shares.grant(note.id, sharee.id, 'editor');

    await freeze(sharee, note.id).expect(403);
    await freeze(owner, note.id).expect(200);
    expect((await sharee.notes.read(note.id)).isFrozen).toBe(true);
    await sharee.http
      .patch(`/api/notes/${note.id}`)
      .send({ title: 'm' })
      .expect(403);
  });

  it('freezes a selection of owned notes', async () => {
    const a = await owner.notes.create({ title: 'a' });
    const b = await owner.notes.create({ title: 'b' });
    const theirs = await sharee.notes.create({ title: 'c' });
    await sharee.shares.grant(theirs.id, owner.id, 'editor');

    await owner.http
      .post('/api/notes/bulk/freeze')
      .send({ noteIds: [a.id, b.id, theirs.id], isFrozen: true })
      .expect(201, { count: 2 });
    expect((await owner.notes.read(a.id)).isFrozen).toBe(true);
    expect((await owner.notes.read(theirs.id)).isFrozen).toBe(false);
  });

  it('a trashed note cannot be frozen', async () => {
    const note = await owner.notes.create();
    await owner.notes.trash(note.id);
    await freeze(owner, note.id).expect(400);
  });

  it('the sync carries the freeze and refuses writes to a frozen note', async () => {
    const note = await owner.notes.create({ title: 'n', content: 'x' });
    const before = await owner.sync.drain();

    const frozen = await owner.sync.push([
      { type: 'note', id: note.id, baseVersion: 1, title: 'n', isFrozen: true },
    ]);
    expect(frozen.results[0]).toMatchObject({ status: 'applied', version: 2 });
    const after = await owner.sync.drain({ cursor: before.cursor });
    expect(entryFor(after.entries, 'note', note.id).note).toMatchObject({
      isFrozen: true,
    });

    const edit = await owner.sync.push([
      { type: 'note', id: note.id, baseVersion: 2, title: 'n', content: 'y' },
    ]);
    expect(edit.results[0]).toMatchObject({
      status: 'conflict',
      serverCopy: { content: 'x', isFrozen: true },
    });
    const trash = await owner.sync.push([
      {
        type: 'note',
        id: note.id,
        baseVersion: 2,
        title: 'n',
        state: 'trashed',
      },
    ]);
    expect(trash.results[0].status).toBe('conflict');
    expect((await owner.notes.read(note.id)).state).toBe('active');

    // Unfreezing and editing in one push lands.
    const unfrozen = await owner.sync.push([
      {
        type: 'note',
        id: note.id,
        baseVersion: 2,
        title: 'n',
        content: 'y',
        isFrozen: false,
      },
    ]);
    expect(unfrozen.results[0]).toMatchObject({
      status: 'applied',
      version: 3,
    });
    expect(await owner.notes.read(note.id)).toMatchObject({
      content: 'y',
      isFrozen: false,
    });
  });
});
