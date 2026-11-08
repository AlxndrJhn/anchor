// Writes test/fixtures/collab-ot-vectors.json: what quill-delta answers for
// random changes, which the web and app clients must answer alike.
import { writeFileSync } from 'node:fs';
import { createRequire } from 'node:module';

const Delta = createRequire(import.meta.url)('quill-delta').default;

let seed = 20261108;
const random = (n) => {
  seed = (seed * 1664525 + 1013904223) % 4294967296;
  return Math.floor((seed / 4294967296) * n);
};
const pieces = ['a', 'hi', 'wörld', '😀', 'x😀y', '\n', 'line\n', ' '];
const attributes = [
  undefined,
  undefined,
  { bold: true },
  { list: 'checked' },
  { italic: true, color: '#ff0000' },
  { bold: null },
];
const insert = (delta) => {
  // Text in a note never holds a format set to null; only a change does.
  const picked = attributes[random(attributes.length)];
  const attrs = picked?.bold === null ? undefined : picked;
  if (random(8) === 0) delta.insert({ image: `id${random(9)}` }, attrs);
  else delta.insert(pieces[random(pieces.length)], attrs);
};
const makeDoc = () => {
  const doc = new Delta();
  for (let i = random(6) + 1; i > 0; i--) insert(doc);
  return doc.insert('\n');
};
const makeChange = (length) => {
  const change = new Delta();
  let at = 0;
  for (let i = random(4) + 1; i > 0 && at < length - 1; i--) {
    const step = random(Math.min(length - 1 - at, 6)) + 1;
    switch (random(4)) {
      case 0:
        change.retain(step);
        at += step;
        break;
      case 1:
        change.retain(step, attributes[random(attributes.length)]);
        at += step;
        break;
      case 2:
        change.delete(step);
        at += step;
        break;
      default:
        insert(change);
    }
  }
  return change.ops.length ? change : new Delta().insert('z');
};

const vectors = [];
for (let i = 0; i < 300; i++) {
  const doc = makeDoc();
  const a = makeChange(doc.length());
  const b = makeChange(doc.length());
  const position = random(doc.length());
  vectors.push({
    doc: doc.ops,
    a: a.ops,
    b: b.ops,
    aThenB: doc.compose(a).compose(a.transform(b, true)).ops,
    bThenA: doc.compose(b).compose(b.transform(a, false)).ops,
    bOverA: a.transform(b, true).ops,
    aOverB: b.transform(a, false).ops,
    position,
    positionOverA: a.transformPosition(position),
    positionOverAForced: a.transformPosition(position, true),
  });
}
writeFileSync(
  new URL('../test/fixtures/collab-ot-vectors.json', import.meta.url),
  JSON.stringify(vectors) + '\n',
);
