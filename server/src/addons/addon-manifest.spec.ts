import { readFileSync } from 'node:fs';
import path from 'node:path';
import { describe, expect, it } from 'vitest';
import { PALETTE_FIELDS, checkAddon, cssProblems } from './addon-manifest';

const manifest = (overrides: Record<string, unknown> = {}) => ({
  id: 'dev.example.solarized',
  name: 'Solarized',
  version: '1.0.0',
  anchorApi: 1,
  contributes: { theme: { dark: { accent: '#B58900' } } },
  ...overrides,
});

const errorsOf = (m: unknown, files: unknown = {}) => {
  const check = checkAddon(m, files);
  return check.ok ? [] : check.errors;
};

describe('checkAddon', () => {
  it('keeps a theme, with its colours as the web app writes them', () => {
    expect(checkAddon(manifest(), {})).toEqual({
      ok: true,
      addon: {
        manifest: {
          ...manifest(),
          contributes: { theme: { dark: { accent: '#b58900' } } },
        },
        files: {},
      },
    });
  });

  it('keeps only the style files the addon names', () => {
    const check = checkAddon(
      manifest({ contributes: { styles: ['css/a.css'] } }),
      { 'css/a.css': 'body{color:red}', 'README.md': '# hi' },
    );
    expect(check.ok && check.addon.files).toEqual({
      'css/a.css': 'body{color:red}',
    });
  });

  it('lists every problem', () => {
    expect(
      errorsOf({
        id: 'Solarized',
        name: '',
        version: 'one',
        anchorApi: 1,
        contributes: {},
        colour: 'red',
      }),
    ).toEqual([
      'colour: unknown key',
      'id: use lower-case words with dots, like "dev.example.my-addon"',
      'name: must be text',
      'version: use a version like "1.0.0"',
    ]);
  });

  it('says what needs a newer Anchor+', () => {
    expect(
      errorsOf(
        manifest({
          anchorApi: 2,
          permissions: ['notes:read'],
          contributes: { commands: [] },
        }),
      ),
    ).toEqual([
      'permissions: needs a newer Anchor+',
      'anchorApi 2: needs a newer Anchor+',
      'contributes.commands: needs a newer Anchor+',
    ]);
  });

  it('refuses style files that are missing or reach outside the addon', () => {
    expect(
      errorsOf(manifest({ contributes: { styles: ['../x.css', 'b.css'] } })),
    ).toEqual([
      'contributes.styles: "../x.css" must be a .css file in the addon',
      'contributes.styles: "b.css" is not in the addon',
    ]);
  });

  it('refuses a theme with unknown keys or colours', () => {
    expect(
      errorsOf(
        manifest({
          contributes: { theme: { dark: { acent: '#fff', card: 'red' } } },
        }),
      ),
    ).toEqual([
      'contributes.theme.dark.acent: unknown key',
      'contributes.theme.dark.card: not a colour',
    ]);
  });

  it('refuses files larger than the limit', () => {
    expect(
      errorsOf(manifest({ contributes: { styles: ['a.css'] } }), {
        'a.css': 'a'.repeat(256 * 1024 + 1),
      }),
    ).toEqual(["The addon's files are larger than 256 KB"]);
  });
});

describe('cssProblems', () => {
  it('lets data: URLs and plain CSS through', () => {
    expect(
      cssProblems(
        '/* see https://x.y */ .a{background:url("data:image/png;base64,AA");content:"\\201C"}',
      ),
    ).toEqual([]);
  });

  it.each([
    ['@import "x.css";', '@import is not allowed'],
    [
      'a{background:url(https://evil.example/x)}',
      'url() may only hold a data: URL',
    ],
    ["a{background:url( 'img.png')}", 'url() may only hold a data: URL'],
    [
      'a{background:image-set("https://e.x/a.png" 1x)}',
      'url() may only hold a data: URL',
    ],
    [
      'a{background:\\75rl(x)}',
      'escapes like \\75 are only allowed inside strings',
    ],
  ])('refuses %s', (css, problem) => {
    expect(cssProblems(css)).toContain(problem);
  });
});

describe('PALETTE_FIELDS', () => {
  it('are the colour schemes’ fields', () => {
    const schemes = JSON.parse(
      readFileSync(
        path.resolve(__dirname, '../../../design/schemes/schemes.json'),
        'utf8',
      ),
    ) as { schemes: { light: Record<string, string> }[] };
    expect([...PALETTE_FIELDS].sort()).toEqual(
      Object.keys(schemes.schemes[0].light).sort(),
    );
  });
});
