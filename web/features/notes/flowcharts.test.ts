import { describe, expect, it } from "vitest";
import {
  encodeFlowchart,
  FLOWCHART_EMBED,
  type Flowchart,
  flowchartBounds,
  flowchartSvg,
  flowchartsIn,
  flowchartText,
  flowEdgeEnds,
  flowNodeAt,
  flowNodeSize,
  parseFlowchart,
  starterFlowchart,
  wrapFlowText,
} from "./flowcharts";
import { deltaToFullPlainText } from "./quill";

const chart: Flowchart = {
  nodes: [
    { id: "a", x: 0, y: 0, text: "Start", shape: "round" },
    { id: "b", x: 0, y: 200, text: "Is it <ok>?", shape: "diamond" },
  ],
  edges: [{ id: "e", from: "a", to: "b", text: "next" }],
};

describe("flowcharts", () => {
  it("reads back what it writes", () => {
    expect(parseFlowchart(encodeFlowchart(chart))).toEqual(chart);
  });

  it("drops what it can't draw", () => {
    const parsed = parseFlowchart(
      JSON.stringify({
        nodes: [
          { id: "a", x: 1.6, y: "x", text: 5, shape: "star" },
          { id: "a", x: 0, y: 0 },
          { x: 0, y: 0 },
        ],
        edges: [
          { id: "e1", from: "a", to: "gone" },
          { id: "e2", from: "a", to: "a" },
        ],
      }),
    );
    expect(parsed).toEqual({
      nodes: [{ id: "a", x: 2, y: 0, text: "", shape: "box" }],
      edges: [],
    });
    expect(parseFlowchart("not json")).toBeNull();
    expect(parseFlowchart(JSON.stringify({ edges: [] }))).toBeNull();
  });

  it("starts with a start joined to a step", () => {
    let n = 0;
    const starter = starterFlowchart(() => `id${n++}`);
    expect(starter.nodes.map((node) => node.shape)).toEqual(["round", "box"]);
    expect(starter.edges).toEqual([{ id: "id2", from: "id0", to: "id1" }]);
  });

  it("wraps text at words, and long words where they must", () => {
    expect(wrapFlowText("Check the order and send it", "box")).toEqual([
      "Check the order",
      "and send it",
    ]);
    expect(wrapFlowText("a\nb", "box")).toEqual(["a", "b"]);
    expect(wrapFlowText("x".repeat(20), "box")).toEqual(["x".repeat(18), "xx"]);
    expect(wrapFlowText("", "box")).toEqual([""]);
  });

  it("grows a box with its lines", () => {
    const one = flowNodeSize({ text: "One", shape: "box" }).height;
    const three = flowNodeSize({ text: "a\nb\nc", shape: "box" }).height;
    expect(three).toBeGreaterThan(one);
  });

  it("ends arrows on the outlines", () => {
    const { start, end } = flowEdgeEnds(chart.nodes[0], chart.nodes[1]);
    const startHeight = flowNodeSize(chart.nodes[0]).height;
    const endHeight = flowNodeSize(chart.nodes[1]).height;
    expect(start).toEqual({ x: 0, y: startHeight / 2 });
    expect(end).toEqual({ x: 0, y: 200 - endHeight / 2 });
  });

  it("finds the node under a point and the chart's box", () => {
    expect(flowNodeAt(chart, { x: 10, y: 5 })?.id).toBe("a");
    expect(flowNodeAt(chart, { x: 500, y: 0 })).toBeNull();
    const box = flowchartBounds(chart);
    expect(box?.left).toBe(-85);
    expect(flowchartBounds({ nodes: [], edges: [] })).toBeNull();
  });

  it("draws safe SVG", () => {
    const svg = flowchartSvg(chart, "Flowchart: Start");
    expect(svg).toContain("Is it &#60;ok&#62;?");
    expect(svg).not.toContain("<ok>");
    expect(svg).toContain('marker-end="url(#fc-arrow-');
  });

  it("finds charts in a note and their words", () => {
    const content = JSON.stringify({
      ops: [
        { insert: "Plan\n" },
        { insert: { [FLOWCHART_EMBED]: encodeFlowchart(chart) } },
        { insert: "\n" },
      ],
    });
    expect(flowchartsIn(content)).toEqual([chart]);
    expect(flowchartText(chart)).toBe("Start Is it <ok>? next");
    expect(deltaToFullPlainText(content)).toBe("Plan Start Is it <ok>? next");
  });
});
