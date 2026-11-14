import { QuillOp } from './delta-lines';

/**
 * A flowchart placed in a note's text: `{"insert": {"flowchart": "<json>"}}`
 * (web/features/notes/flowcharts.ts). Markdown has no flowcharts, so they are
 * written as Mermaid, which most Markdown viewers draw.
 */
export const FLOWCHART_EMBED = 'flowchart';

type Node = { id: string; text: string; shape: string };
type Edge = { from: string; to: string; text?: string };

function parse(value: unknown): { nodes: Node[]; edges: Edge[] } | null {
  if (typeof value !== 'string') return null;
  let data: unknown;
  try {
    data = JSON.parse(value);
  } catch {
    return null;
  }
  if (!data || typeof data !== 'object') return null;
  const { nodes, edges } = data as { nodes?: unknown; edges?: unknown };
  if (!Array.isArray(nodes)) return null;
  const kept: Node[] = [];
  const ids = new Set<string>();
  for (const raw of nodes) {
    const node = raw as Record<string, unknown> | null;
    if (!node || typeof node.id !== 'string' || ids.has(node.id)) continue;
    ids.add(node.id);
    kept.push({
      id: node.id,
      text: typeof node.text === 'string' ? node.text : '',
      shape: typeof node.shape === 'string' ? node.shape : 'box',
    });
  }
  const joins: Edge[] = [];
  for (const raw of Array.isArray(edges) ? edges : []) {
    const edge = raw as Record<string, unknown> | null;
    if (
      !edge ||
      typeof edge.from !== 'string' ||
      typeof edge.to !== 'string' ||
      !ids.has(edge.from) ||
      !ids.has(edge.to)
    )
      continue;
    joins.push({
      from: edge.from,
      to: edge.to,
      text: typeof edge.text === 'string' ? edge.text : undefined,
    });
  }
  return { nodes: kept, edges: joins };
}

/** Mermaid's quoted label, with the characters it can't hold escaped. */
function label(text: string): string {
  const clean = text.replace(/\s+/g, ' ').trim().replace(/"/g, '#quot;');
  return `"${clean || ' '}"`;
}

/** The flowchart in an op, or null when the op isn't one. */
export function flowchartOf(op: QuillOp): string | null {
  const insert = op.insert;
  if (!insert || typeof insert !== 'object') return null;
  const value = (insert as Record<string, unknown>)[FLOWCHART_EMBED];
  return value === undefined ? null : typeof value === 'string' ? value : '';
}

/** The chart as Mermaid lines, without the fence; empty when unreadable. */
export function flowchartToMermaid(value: string): string[] {
  const chart = parse(value);
  if (!chart) return [];
  const name = new Map(chart.nodes.map((node, i) => [node.id, `n${i + 1}`]));
  const lines = ['flowchart TD'];
  for (const node of chart.nodes) {
    const id = name.get(node.id)!;
    const text = label(node.text);
    lines.push(
      node.shape === 'diamond'
        ? `  ${id}{${text}}`
        : node.shape === 'round'
          ? `  ${id}([${text}])`
          : `  ${id}[${text}]`,
    );
  }
  for (const edge of chart.edges) {
    const arrow = edge.text?.trim() ? `-->|${label(edge.text)}|` : '-->';
    lines.push(`  ${name.get(edge.from)} ${arrow} ${name.get(edge.to)}`);
  }
  return lines;
}
