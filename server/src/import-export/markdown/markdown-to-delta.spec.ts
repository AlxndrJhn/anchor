import { describe, expect, it } from 'vitest';
import { markdownToDelta, parseInline } from './markdown-to-delta';
import { roundTripCases } from './__fixtures__/roundtrip';

describe('parseInline', () => {
  it('keeps the formats the editor supports', () => {
    expect(parseInline('**bold** and ==marked== [link](https://a.b)')).toEqual([
      { insert: 'bold', attributes: { bold: true } },
      { insert: ' and ' },
      { insert: 'marked', attributes: { highlight: 'yellow' } },
      { insert: ' ' },
      { insert: 'link', attributes: { link: 'https://a.b' } },
    ]);
  });

  it('leaves underscores inside words alone', () => {
    expect(parseInline('snake_case_name')).toEqual([
      { insert: 'snake_case_name' },
    ]);
  });
});

describe('markdownToDelta', () => {
  it('ends empty text with the newline Quill needs', () => {
    expect(markdownToDelta('')).toEqual({ ops: [{ insert: '\n' }] });
  });

  it('turns task items into checklist lines', () => {
    expect(markdownToDelta('- [ ] milk\n- [x] eggs').ops).toEqual([
      { insert: 'milk' },
      { insert: '\n', attributes: { list: 'unchecked' } },
      { insert: 'eggs' },
      { insert: '\n', attributes: { list: 'checked' } },
    ]);
  });

  it.each(roundTripCases)('parses the $name fixture', ({ markdown, ops }) => {
    expect(markdownToDelta(markdown)).toEqual({ ops });
  });
});
