import { beforeEach, describe, expect, it, vi } from 'vitest';
import sharp from 'sharp';
import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';
import {
  BEST_WINDOW,
  MIN_SCORE,
  PictureSearchService,
  bestMatches,
} from './picture-search.service';
import { imagePixels, tokenIds, type PictureModel } from './picture-model';
import type { PrismaService } from '../prisma/prisma.service';

describe('bestMatches', () => {
  it('keeps close matches, each note once by its best picture, best first', () => {
    const matches = bestMatches([
      { noteId: 'cats', attachmentId: 'c1', score: 0.08 },
      { noteId: 'cats', attachmentId: 'c2', score: 0.11 },
      { noteId: 'tiger', attachmentId: 't1', score: 0.12 },
      // Far behind the best.
      { noteId: 'bread', attachmentId: 'b1', score: 0.12 - BEST_WINDOW - 0.01 },
      // Too far from the description at all.
      { noteId: 'street', attachmentId: 's1', score: MIN_SCORE - 0.01 },
    ]);

    expect(matches).toEqual([
      { noteId: 'tiger', attachmentId: 't1', score: 0.12 },
      { noteId: 'cats', attachmentId: 'c2', score: 0.11 },
    ]);
  });

  it('finds nothing when nothing looks like it', () => {
    expect(
      bestMatches([{ noteId: 'n', attachmentId: 'a', score: 0.02 }]),
    ).toEqual([]);
  });
});

describe('tokenIds', () => {
  it('lowercases the description and pads it to 64', () => {
    const encode = vi.fn(() => ({ ids: [5, 6, 1] }));

    const ids = tokenIds({ encode }, 'Zwei Katzen', 0);

    expect(encode).toHaveBeenCalledWith('zwei katzen');
    expect(ids).toHaveLength(64);
    expect(ids.slice(0, 4)).toEqual([5, 6, 1, 0]);
  });

  it('cuts a long description at 64', () => {
    const ids = tokenIds(
      { encode: () => new Array<number>(100).fill(7) },
      'x',
      0,
    );
    expect(ids).toHaveLength(64);
  });
});

describe('imagePixels', () => {
  it('makes a 224 × 224 picture, channels first, from -1 to 1', async () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'pixels-'));
    const file = path.join(dir, 'red.png');
    await sharp({
      create: { width: 40, height: 20, channels: 4, background: '#ff0000' },
    })
      .png()
      .toFile(file);

    const pixels = await imagePixels(file);

    expect(pixels).toHaveLength(3 * 224 * 224);
    const area = 224 * 224;
    expect(pixels[0]).toBeCloseTo(1); // red
    expect(pixels[area]).toBeCloseTo(-1); // green
    expect(pixels[2 * area]).toBeCloseTo(-1); // blue
  });
});

describe('PictureSearchService', () => {
  /** Unit vectors along one axis: "cat" pictures and queries share one. */
  const axis = (i: number) => {
    const v = new Float32Array(4);
    v[i] = 1;
    return v;
  };
  const model = {
    state: { state: 'ready' },
    ensureDownloaded: vi.fn().mockResolvedValue(undefined),
    embedImage: vi.fn((file: string) =>
      Promise.resolve(file.includes('cat') ? axis(0) : axis(1)),
    ),
    embedText: vi.fn((q: string) =>
      Promise.resolve(q.toLowerCase().includes('katze') ? axis(0) : axis(2)),
    ),
  };

  let optedIn: boolean;
  let pictures: { id: string; noteId: string; storedFilename: string }[];
  let embeddings: Map<string, Uint8Array>;
  let service: PictureSearchService;

  const prisma = {
    user: {
      findUnique: vi.fn(() => Promise.resolve({ pictureSearch: optedIn })),
      update: vi.fn(({ data }: { data: { pictureSearch: boolean } }) => {
        optedIn = data.pictureSearch;
        return Promise.resolve({});
      }),
    },
    noteAttachment: {
      findMany: vi.fn(({ where }: { where: { embedding: unknown } }) =>
        Promise.resolve(
          pictures.filter((p) =>
            where.embedding === null
              ? optedIn && !embeddings.has(p.id)
              : embeddings.has(p.id),
          ),
        ),
      ),
      count: vi.fn(({ where }: { where: { embedding?: unknown } }) =>
        Promise.resolve(
          where.embedding
            ? pictures.filter((p) => embeddings.has(p.id)).length
            : pictures.length,
        ),
      ),
    },
    pictureEmbedding: {
      create: vi.fn(
        ({ data }: { data: { attachmentId: string; vector: Uint8Array } }) => {
          embeddings.set(data.attachmentId, data.vector);
          return Promise.resolve({});
        },
      ),
      findMany: vi.fn(
        ({ where }: { where: { attachmentId: { in: string[] } } }) =>
          Promise.resolve(
            where.attachmentId.in.map((attachmentId) => ({
              attachmentId,
              vector: embeddings.get(attachmentId)!,
            })),
          ),
      ),
    },
  } as unknown as PrismaService;

  function create(enabled = true) {
    return new PictureSearchService(
      prisma,
      { root: '/data', attachmentsDir: '/data/uploads/attachments' } as never,
      { enabled, modelUrl: undefined },
      model as unknown as PictureModel,
    );
  }

  async function settle(s: PictureSearchService) {
    s.kick();
    await (s as unknown as { running: Promise<void> | null }).running;
  }

  beforeEach(() => {
    vi.clearAllMocks();
    optedIn = false;
    embeddings = new Map();
    pictures = [
      { id: 'a1', noteId: 'n-cat', storedFilename: 'cat.png' },
      { id: 'a2', noteId: 'n-street', storedFilename: 'street.png' },
    ];
    service = create();
  });

  it('indexes nothing until someone turns it on', async () => {
    await settle(service);

    expect(model.ensureDownloaded).not.toHaveBeenCalled();
    expect(model.embedImage).not.toHaveBeenCalled();
  });

  it('turned on, indexes the pictures and finds notes by what they show', async () => {
    const status = await service.setEnabled('u1', true);
    expect(status.enabled).toBe(true);
    await (service as unknown as { running: Promise<void> | null }).running;

    expect(model.ensureDownloaded).toHaveBeenCalled();
    expect(embeddings.size).toBe(2);
    expect(await service.status('u1')).toMatchObject({
      enabled: true,
      indexed: 2,
      total: 2,
    });

    const found = await service.search('u1', 'Zwei Katzen');
    expect(found.map((m) => m.noteId)).toEqual(['n-cat']);
    expect(await service.search('u1', 'Sonnenuntergang')).toEqual([]);
  });

  it('searches nothing for a user who has it off', async () => {
    embeddings.set('a1', new Uint8Array(axis(0).buffer));

    expect(await service.search('u1', 'katze')).toEqual([]);
    expect(model.embedText).not.toHaveBeenCalled();
  });

  it('is not offered when PICTURE_SEARCH is off', async () => {
    const off = create(false);

    const status = await off.setEnabled('u1', true);

    expect(status).toMatchObject({ available: false, enabled: false });
    expect(optedIn).toBe(false);
  });
});
