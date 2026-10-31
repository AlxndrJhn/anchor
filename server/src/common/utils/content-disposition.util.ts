/**
 * A Content-Disposition header that keeps [filename] as it was named: the
 * real name in `filename*` (RFC 6266), and an ASCII stand-in for clients
 * that only read `filename`.
 */
export function contentDisposition(
  type: 'inline' | 'attachment',
  filename: string,
): string {
  const ascii = filename
    .normalize('NFD')
    .replace(/\p{M}/gu, '')
    .replace(/[^\x20-\x7e]|["\\]/g, '_');
  const encoded = encodeURIComponent(filename).replace(
    /['()*]/g,
    (c) => `%${c.charCodeAt(0).toString(16).toUpperCase()}`,
  );
  return `${type}; filename="${ascii}"; filename*=UTF-8''${encoded}`;
}
