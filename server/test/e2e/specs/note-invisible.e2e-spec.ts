import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { Actor, createE2EApp, E2EApp, entryFor } from '../support';

/**
 * Invisible belongs to the person, like a pin or a lock: their apps leave
 * the note out of their lists and only search finds it. The note isn't
 * changed.
 */
describe('invisible notes', () => {
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

  it('makes a note invisible for its person only, and shows it again', async () => {
    const note = await owner.notes.create({ title: 'secret', content: 'x' });
    await owner.shares.grant(note.id, sharee.id, 'viewer');
    expect((await owner.notes.read(note.id)).isInvisible).toBe(false);

    await owner.http
      .patch(`/api/notes/${note.id}/invisible`)
      .send({ isInvisible: true })
      .expect(200, { id: note.id, isInvisible: true });

    expect((await owner.notes.read(note.id)).isInvisible).toBe(true);
    expect((await owner.notes.list())[0].isInvisible).toBe(true);
    expect((await sharee.notes.read(note.id)).isInvisible).toBe(false);

    await owner.http
      .patch(`/api/notes/${note.id}/invisible`)
      .send({ isInvisible: false })
      .expect(200);
    expect((await owner.notes.read(note.id)).isInvisible).toBe(false);
  });

  it('makes a selection invisible at once', async () => {
    const a = await owner.notes.create({ title: 'a' });
    const b = await owner.notes.create({ title: 'b' });

    await owner.http
      .post('/api/notes/bulk/invisible')
      .send({ noteIds: [a.id, b.id], isInvisible: true })
      .expect(201, { count: 2 });

    const flags = (await owner.notes.list()).map((n) => n.isInvisible);
    expect(flags).toEqual([true, true]);
  });

  it('the sync carries it both ways', async () => {
    const note = await owner.notes.create({ title: 'n' });
    const before = await owner.sync.drain();

    const res = await owner.sync.push([
      {
        type: 'note',
        id: note.id,
        baseVersion: 1,
        title: 'n',
        isInvisible: true,
      },
    ]);
    expect(res.results[0].status).toBe('applied');
    expect((await owner.notes.read(note.id)).isInvisible).toBe(true);

    const after = await owner.sync.drain({ cursor: before.cursor });
    const entry = entryFor(after.entries, 'note', note.id);
    expect(entry.note).toMatchObject({ isInvisible: true });

    await owner.sync.push([
      {
        type: 'note',
        id: note.id,
        baseVersion: 1,
        title: 'n',
        isInvisible: false,
      },
    ]);
    expect((await owner.notes.read(note.id)).isInvisible).toBe(false);
  });
});
