import { describe, expect, it } from 'vitest';
import { contentDisposition } from './content-disposition.util';

describe('contentDisposition', () => {
  it('keeps a plain name as it is', () => {
    expect(contentDisposition('attachment', 'notes.pdf')).toBe(
      `attachment; filename="notes.pdf"; filename*=UTF-8''notes.pdf`,
    );
  });

  it('gives the real name to clients that read filename*', () => {
    expect(contentDisposition('inline', 'Äpfel (1).jpg')).toBe(
      `inline; filename="Apfel (1).jpg"; filename*=UTF-8''%C3%84pfel%20%281%29.jpg`,
    );
  });

  it('keeps quotes and other letters out of the plain name', () => {
    expect(contentDisposition('attachment', 'a"b\\c 日本.txt')).toBe(
      `attachment; filename="a_b_c __.txt"; filename*=UTF-8''a%22b%5Cc%20%E6%97%A5%E6%9C%AC.txt`,
    );
  });
});
