import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import request from 'supertest';
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StreamableHTTPClientTransport } from '@modelcontextprotocol/sdk/client/streamableHttp.js';
import { Actor, createE2EApp, E2EApp } from '../support';
import { PNG_1PX } from '../support/fixtures';

/**
 * Claude's way in: the MCP endpoint, driven with the SDK's own client and
 * the user's token, as Claude Code or Claude Desktop would.
 */
describe('mcp', () => {
  let ctx: E2EApp;
  let user: Actor;
  let client: Client;

  const call = async (name: string, args: Record<string, unknown> = {}) => {
    const result = await client.callTool({ name, arguments: args });
    const [content] = result.content as { type: 'text'; text: string }[];
    return { isError: result.isError === true, text: content.text };
  };
  const json = async <T>(name: string, args: Record<string, unknown> = {}) => {
    const { isError, text } = await call(name, args);
    expect(isError, text).toBe(false);
    return JSON.parse(text) as T;
  };

  type NoteResult = {
    id: string;
    title: string;
    version: number;
    tags: string[];
    content: string | null;
    locked?: boolean;
  };

  beforeAll(async () => {
    ctx = await createE2EApp();
  });

  afterAll(async () => {
    await ctx.close();
  });

  beforeEach(async () => {
    await ctx.resetDb();
    user = await ctx.registerUser();
    const { port } = ctx.address;
    client = new Client({ name: 'e2e', version: '1.0.0' });
    await client.connect(
      new StreamableHTTPClientTransport(
        new URL(`http://127.0.0.1:${port}/api/mcp`),
        { requestInit: { headers: user.auth } },
      ),
    );
  });

  it('turns away requests without a token', async () => {
    await request(ctx.http)
      .post('/api/mcp')
      .send({ jsonrpc: '2.0', id: 1, method: 'tools/list' })
      .expect(401);
  });

  it('lists its tools', async () => {
    const { tools } = await client.listTools();

    expect(tools.map((tool) => tool.name).sort()).toEqual([
      'append_to_note',
      'create_note',
      'get_attachment',
      'get_note',
      'list_notes',
      'list_tags',
      'trash_note',
      'update_note',
    ]);
  });

  it('creates a note from markdown, with new tags', async () => {
    const created = await json<NoteResult>('create_note', {
      title: 'Groceries',
      content: '- [ ] milk\n- [x] eggs\n',
      tags: ['Shopping'],
    });

    const stored = await user.notes.read(created.id);
    expect(stored.title).toBe('Groceries');
    expect(JSON.parse(stored.content!)).toEqual({
      ops: [
        { insert: 'milk' },
        { insert: '\n', attributes: { list: 'unchecked' } },
        { insert: 'eggs' },
        { insert: '\n', attributes: { list: 'checked' } },
      ],
    });
    expect(created.tags).toEqual(['Shopping']);
    expect(await json('list_tags')).toEqual([
      { id: stored.tagIds[0], name: 'Shopping', notes: 1 },
    ]);
  });

  it('reads a note as markdown', async () => {
    const note = await user.notes.create({
      title: 'Plan',
      content: JSON.stringify({
        ops: [
          { insert: 'Today' },
          { insert: '\n', attributes: { header: 1 } },
          { insert: 'ship', attributes: { bold: true } },
          { insert: '\n' },
        ],
      }),
    });

    const read = await json<NoteResult>('get_note', { id: note.id });

    expect(read).toMatchObject({
      id: note.id,
      title: 'Plan',
      version: note.version,
      content: '# Today\n**ship**\n',
    });
  });

  it('searches, and leaves invisible notes to searches', async () => {
    await user.notes.create({ title: 'Seen', content: null });
    const hidden = await user.notes.create({ title: 'Hidden', content: null });
    await user.http
      .patch(`/api/notes/${hidden.id}/invisible`)
      .send({ isInvisible: true })
      .expect(200);

    const all = await json<{ notes: NoteResult[] }>('list_notes');
    expect(all.notes.map((n) => n.title)).toEqual(['Seen']);

    const found = await json<{ notes: NoteResult[] }>('list_notes', {
      query: 'hid',
    });
    expect(found.notes.map((n) => n.title)).toEqual(['Hidden']);

    // Nor does the archive list it until it is searched for.
    await user.http
      .post('/api/notes/bulk/archive')
      .send({ noteIds: [hidden.id] })
      .expect(201);
    const archived = await json<{ notes: NoteResult[] }>('list_notes', {
      scope: 'archive',
    });
    expect(archived.notes).toEqual([]);
    const foundArchived = await json<{ notes: NoteResult[] }>('list_notes', {
      scope: 'archive',
      query: 'hid',
    });
    expect(foundArchived.notes.map((n) => n.title)).toEqual(['Hidden']);
  });

  it('changes a note, refusing a stale version', async () => {
    const note = await user.notes.create({ title: 'Old', content: null });

    const updated = await json<NoteResult>('update_note', {
      id: note.id,
      version: note.version,
      title: 'New',
      content: 'Some *text*',
    });
    expect(updated).toMatchObject({ title: 'New', content: 'Some *text*\n' });

    const stale = await call('update_note', {
      id: note.id,
      version: note.version,
      title: 'Lost',
    });
    expect(stale.isError).toBe(true);
    expect((await user.notes.read(note.id)).title).toBe('New');
  });

  it('adds lines to the end of a note', async () => {
    const note = await user.notes.create({
      title: 'List',
      content: JSON.stringify({
        ops: [
          { insert: 'milk' },
          { insert: '\n', attributes: { list: 'unchecked' } },
        ],
      }),
    });

    const appended = await json<NoteResult>('append_to_note', {
      id: note.id,
      content: '- [ ] bread',
    });

    expect(appended.content).toBe('- [ ] milk\n- [ ] bread\n');
  });

  it('keeps a picture in the text from being rewritten away', async () => {
    const content = JSON.stringify({
      ops: [{ insert: { image: 'attachment:abc' } }, { insert: '\n' }],
    });
    const note = await user.notes.create({ title: 'Pic', content });

    const refused = await call('update_note', { id: note.id, content: 'x' });

    expect(refused.isError).toBe(true);
    expect((await user.notes.read(note.id)).content).toBe(content);
  });

  it('keeps a locked note to itself', async () => {
    const note = await user.notes.create({
      title: 'Diary',
      content: JSON.stringify({ ops: [{ insert: 'secret\n' }] }),
    });
    await user.http
      .patch(`/api/notes/${note.id}/lock`)
      .send({ lock: 'pin' })
      .expect(200);

    const read = await json<NoteResult>('get_note', { id: note.id });
    expect(read).toMatchObject({ locked: true, content: null });

    const listed = await call('list_notes', { query: 'secret' });
    expect(listed.text).not.toContain('secret');
    // Found by its title alone: a word of its text doesn't bring it up.
    expect(listed.text).not.toContain('Diary');

    const append = await call('append_to_note', { id: note.id, content: 'x' });
    expect(append.isError).toBe(true);
  });

  it('lists the attachments of a note', async () => {
    const note = await user.notes.create({ title: 'Snap', content: null });
    const picture = await user.attachments.upload(note.id, 'snap.png');

    const read = await json<{ attachments: unknown[] }>('get_note', {
      id: note.id,
    });
    expect(read.attachments).toEqual([
      expect.objectContaining({
        id: picture.id,
        type: 'image',
        filename: 'snap.png',
        mimeType: 'image/png',
      }),
    ]);

    const listed = await json<{ notes: { attachments?: number }[] }>(
      'list_notes',
    );
    expect(listed.notes[0].attachments).toBe(1);
  });

  it('hands over a picture as an image', async () => {
    const note = await user.notes.create({ title: 'Snap', content: null });
    const picture = await user.attachments.upload(note.id, 'snap.png');

    const result = await client.callTool({
      name: 'get_attachment',
      arguments: { noteId: note.id, id: picture.id },
    });

    expect(result.isError).toBeFalsy();
    expect(result.content).toEqual([
      expect.objectContaining({ type: 'text' }),
      {
        type: 'image',
        mimeType: 'image/png',
        data: PNG_1PX.toString('base64'),
      },
    ]);
  });

  it('hands over a text file as its text', async () => {
    const note = await user.notes.create({ title: 'Doc', content: null });
    const res = await user.http
      .post(`/api/notes/${note.id}/attachments`)
      .attach('file', Buffer.from('hello'), {
        filename: 'a.txt',
        contentType: 'text/plain',
      })
      .expect(201);
    const file = res.body as { id: string };

    const result = await client.callTool({
      name: 'get_attachment',
      arguments: { noteId: note.id, id: file.id },
    });

    expect(result.content).toContainEqual({
      type: 'resource',
      resource: expect.objectContaining({ text: 'hello' }) as unknown,
    });
  });

  it('keeps the attachments of a locked note to itself', async () => {
    const note = await user.notes.create({ title: 'Diary', content: null });
    const picture = await user.attachments.upload(note.id);
    await user.http
      .patch(`/api/notes/${note.id}/lock`)
      .send({ lock: 'pin' })
      .expect(200);

    const read = await json<{ attachments: unknown }>('get_note', {
      id: note.id,
    });
    expect(read.attachments).toBe(1);

    const fetched = await call('get_attachment', {
      noteId: note.id,
      id: picture.id,
    });
    expect(fetched.isError).toBe(true);
  });

  it('moves a note to the trash', async () => {
    const note = await user.notes.create({ title: 'Bin me', content: null });

    await call('trash_note', { id: note.id });

    const trash = await json<{ notes: NoteResult[] }>('list_notes', {
      scope: 'trash',
    });
    expect(trash.notes.map((n) => n.id)).toEqual([note.id]);
  });

  it("does not reach other people's notes", async () => {
    const other = await ctx.registerUser();
    const note = await other.notes.create({ title: 'Theirs', content: null });

    const read = await call('get_note', { id: note.id });

    expect(read.isError).toBe(true);
  });
});
