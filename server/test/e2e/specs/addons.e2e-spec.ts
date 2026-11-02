import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { Actor, createE2EApp, E2EApp } from '../support';

/**
 * Each person's addons: installed with their manifest checked, updated by
 * their id, turned on or off, removed, and never seen by anyone else.
 */
describe('addons', () => {
  let ctx: E2EApp;
  let owner: Actor;
  let other: Actor;

  beforeAll(async () => {
    ctx = await createE2EApp();
  });

  afterAll(async () => {
    await ctx.close();
  });

  beforeEach(async () => {
    await ctx.resetDb();
    owner = await ctx.registerUser('Owner');
    other = await ctx.registerUser('Other');
  });

  const manifest = (version = '1.0.0') => ({
    id: 'dev.example.paper',
    name: 'Paper',
    version,
    anchorApi: 1,
    contributes: {
      theme: { dark: { card: '#2A2622' } },
      styles: ['style.css'],
    },
  });
  const files = { 'style.css': ':root{--radius-card:4px}', 'notes.txt': 'x' };

  it('installs, updates, turns off and removes an addon', async () => {
    const installed = await owner.http
      .post('/api/addons')
      .send({ manifest: manifest(), files })
      .expect(201);
    expect(installed.body).toMatchObject({
      addonId: 'dev.example.paper',
      version: '1.0.0',
      enabled: true,
      manifest: { contributes: { theme: { dark: { card: '#2a2622' } } } },
      files: { 'style.css': ':root{--radius-card:4px}' },
    });
    const id = (installed.body as { id: string }).id;

    await owner.http
      .patch(`/api/addons/${id}`)
      .send({ enabled: false })
      .expect(200);
    const updated = await owner.http
      .post('/api/addons')
      .send({ manifest: manifest('1.1.0'), files })
      .expect(201);
    expect(updated.body).toMatchObject({
      id,
      version: '1.1.0',
      enabled: false,
    });

    const list = await owner.http.get('/api/addons').expect(200);
    expect(list.body).toHaveLength(1);

    await owner.http.delete(`/api/addons/${id}`).expect(200);
    expect((await owner.http.get('/api/addons').expect(200)).body).toEqual([]);
  });

  it('refuses an invalid addon, listing every problem', async () => {
    const res = await owner.http
      .post('/api/addons')
      .send({
        manifest: { ...manifest(), version: 'one', contributes: { hooks: [] } },
        files: {},
      })
      .expect(400);
    expect(res.body).toMatchObject({
      errors: [
        'version: use a version like "1.0.0"',
        'contributes.hooks: needs a newer Anchor+',
      ],
    });
  });

  it("keeps each person's addons to themselves", async () => {
    const installed = await owner.http
      .post('/api/addons')
      .send({ manifest: manifest(), files })
      .expect(201);
    const id = (installed.body as { id: string }).id;

    expect((await other.http.get('/api/addons').expect(200)).body).toEqual([]);
    await other.http
      .patch(`/api/addons/${id}`)
      .send({ enabled: false })
      .expect(404);
    await other.http.delete(`/api/addons/${id}`).expect(404);
  });
});
