import { describe, expect, it } from 'vitest';
import { deltaToMarkdown } from './delta-to-markdown';
import { scanToMarkdown } from './scan-markdown';

describe('scanToMarkdown', () => {
  it('names the scan and counts its pages', () => {
    expect(
      scanToMarkdown(
        JSON.stringify({
          title: 'Tax *2026*',
          pages: [{ id: 'a' }, { id: 'b', profile: 'bw' }, { nope: 1 }],
        }),
      ),
    ).toBe(String.raw`**Tax \*2026\*** (2 pages)`);
    expect(scanToMarkdown('{"pages":[{"id":"a"}]}')).toBe('**Scan** (1 page)');
  });

  it('writes nothing for what it cannot read', () => {
    expect(scanToMarkdown('not json')).toBeNull();
    expect(scanToMarkdown('{"pages":[]}')).toBeNull();
  });

  it('stands on a line of its own in the note', () => {
    expect(
      deltaToMarkdown([
        { insert: 'Before\n' },
        { insert: { scan: '{"title":"Lease","pages":[{"id":"a"}]}' } },
        { insert: '\nAfter\n' },
      ]),
    ).toBe('Before\n**Lease** (1 page)\nAfter\n');
  });
});
