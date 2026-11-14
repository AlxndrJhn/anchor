import { describe, expect, it } from 'vitest';
import { deltaToMarkdown } from './delta-to-markdown';
import { flowchartToMermaid } from './flowchart-mermaid';

const chart = JSON.stringify({
  nodes: [
    { id: 'a', x: 0, y: 0, text: 'Start', shape: 'round' },
    { id: 'b', x: 0, y: 130, text: 'Say "hi"?', shape: 'diamond' },
    { id: 'c', x: 0, y: 260, text: 'Done\nnow', shape: 'box' },
  ],
  edges: [
    { id: 'e1', from: 'a', to: 'b' },
    { id: 'e2', from: 'b', to: 'c', text: 'yes' },
    { id: 'e3', from: 'b', to: 'gone' },
  ],
});

describe('flowchartToMermaid', () => {
  it('writes each shape and labelled arrows', () => {
    expect(flowchartToMermaid(chart)).toEqual([
      'flowchart TD',
      '  n1(["Start"])',
      '  n2{"Say #quot;hi#quot;?"}',
      '  n3["Done now"]',
      '  n1 --> n2',
      '  n2 -->|"yes"| n3',
    ]);
  });

  it('writes nothing for what it cannot read', () => {
    expect(flowchartToMermaid('nope')).toEqual([]);
  });

  it('puts a chart in a note as a mermaid block', () => {
    const markdown = deltaToMarkdown([
      { insert: 'Plan\n' },
      { insert: { flowchart: chart } },
      { insert: '\nAfter\n' },
    ]);
    expect(markdown).toBe(
      [
        'Plan',
        '```mermaid',
        ...flowchartToMermaid(chart),
        '```',
        'After',
        '',
      ].join('\n'),
    );
  });
});
