import { describe, expect, it } from 'vitest';
import { replaceAttachmentIds } from './inline-images.util';

const picture = (id: string, caption?: string) => ({
  insert: { 'note-image': JSON.stringify({ id, width: 0.5, caption }) },
});

describe('replaceAttachmentIds', () => {
  it('points inline pictures at their new attachments', () => {
    const content = JSON.stringify({
      ops: [{ insert: 'Hi\n' }, picture('a', 'Cat'), { insert: '\n' }],
    });
    const out = JSON.parse(
      replaceAttachmentIds(content, new Map([['a', 'b']])),
    ) as { ops: { insert: Record<string, string> }[] };
    expect(JSON.parse(out.ops[1].insert['note-image'])).toEqual({
      id: 'b',
      width: 0.5,
      caption: 'Cat',
    });
  });

  it('leaves content without known pictures alone', () => {
    const content = JSON.stringify({ ops: [picture('x'), { insert: '\n' }] });
    expect(replaceAttachmentIds(content, new Map([['a', 'b']]))).toBe(content);
    expect(replaceAttachmentIds('plain', new Map([['a', 'b']]))).toBe('plain');
  });
});
