// @vitest-environment jsdom
import { describe, expect, it } from "vitest";
import { putPictures, takePictures } from "./paste-formatted";

describe("takePictures", () => {
  it("leaves a mark on a line of its own where a picture stood alone", () => {
    const { html, sources } = takePictures(
      '<h2>Result</h2><img src="data:image/png;base64,AAA"><ul><li>one</li></ul>',
    );
    expect(sources).toEqual(["data:image/png;base64,AAA"]);
    expect(html).toBe("<h2>Result</h2><p>0</p><ul><li>one</li></ul>");
  });

  it("keeps a picture inside its line, numbering them in order", () => {
    const { html, sources } = takePictures(
      '<p>See <img src="a.png"> and <img src="b.png"></p><img alt="none">',
    );
    expect(sources).toEqual(["a.png", "b.png"]);
    expect(html).toBe("<p>See 0 and 1</p>");
  });
});

describe("takePictures with tables", () => {
  it("makes each row a line, the header bold", () => {
    const { html } = takePictures(
      "<table><thead><tr><th></th><th>Size</th><th>Price</th></tr></thead>" +
        "<tbody><tr><td>Small</td><td><em>2</em> cm</td><td>3 €</td></tr></tbody></table>",
    );
    expect(html).toBe(
      "<p><strong>Size</strong> | <strong>Price</strong></p>" +
        "<p><span>Small</span> | <span><em>2</em> cm</span> | <span>3 €</span></p>",
    );
  });
});

describe("putPictures", () => {
  it("leaves the name of a picture that couldn't come along", () => {
    const { html, names } = takePictures(
      '<p><button><img alt="chart.png" src="/api/org/files/1/preview"></button></p>',
    );
    expect(putPictures(html, [null], names)).toBe(
      "<p><button>[chart.png]</button></p>",
    );
  });

  it("makes each mark the uploaded picture and drops the rest", () => {
    expect(putPictures("<p>0</p><p>a 1 b</p>", ["x", null])).toBe(
      '<p><span class="note-image" data-value="{&quot;id&quot;:&quot;x&quot;}"></span></p><p>a  b</p>',
    );
  });
});
