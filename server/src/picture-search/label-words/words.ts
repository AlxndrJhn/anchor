import type { LabelWord } from '../labels';

/** Every tag word, in one language. Missing one fails the build. */
export type LabelWords = Record<LabelWord, string>;

/** Old or alternative codes for a language the words come in. */
const ALIASES: Record<string, string> = {
  iw: 'he',
  in: 'id',
  ji: 'yi',
  no: 'nb',
  nn: 'nb',
  fil: 'tl',
  sh: 'sr',
  mo: 'ro',
};

/** Regions that write Chinese in traditional characters. */
const TRADITIONAL = new Set(['tw', 'hk', 'mo']);

/**
 * The best of `languages` for a language tag such as "pt-BR", "zh-TW",
 * "zh-Hant-HK" or "nb_NO", or of an Accept-Language header; English when
 * none fits.
 */
export function labelLanguage(
  tag: string | undefined,
  languages: ReadonlySet<string>,
): string {
  for (const part of (tag ?? '').split(',')) {
    const found = matchOne(part.split(';')[0].trim(), languages);
    if (found) return found;
  }
  return 'en';
}

function matchOne(
  tag: string,
  languages: ReadonlySet<string>,
): string | undefined {
  const parts = tag.replace(/_/g, '-').toLowerCase().split('-');
  const base = ALIASES[parts[0]] ?? parts[0];
  if (!base || base === '*') return undefined;
  if (base === 'zh') {
    const rest = parts.slice(1);
    const traditional =
      rest.includes('hant') ||
      (!rest.includes('hans') && rest.some((p) => TRADITIONAL.has(p)));
    const chinese = traditional ? 'zh-Hant' : 'zh-Hans';
    return languages.has(chinese) ? chinese : undefined;
  }
  return languages.has(base) || base === 'en' ? base : undefined;
}
