"""Prepares the bundled fonts so text in any language draws in one font per
letter. See assets/fonts/README.md.

    python tool/fonts.py noto <google/fonts ofl/notosans dir>
    python tool/fonts.py unmap

`noto` cuts Noto Sans, the fallback, down to Latin (with IPA), Greek and
Cyrillic. It keeps all of Latin, not only the letters our fonts lack, so it
can draw a letter with combining accents whole: given e + U+0323 + U+0302
the shaper needs e as well as the accents in one font, or the cluster falls
apart between fonts.

`unmap` removes characters from the character map of fonts that have them
but draw them wrongly. The glyphs stay; the text then falls back to Noto
Sans as a whole word or letter:

- a few letters of a script the font otherwise lacks, so a Greek word is
  not half Noto and half the font (Nunito's Σ is a summation sign);
- combining accents the font cannot place on letters, as Yoruba's ẹ̀ needs.

Playfair Display keeps its stray Greek letters: its licence reserves the
name for unmodified copies, and Literata, a serif, draws the rest.
"""

import io
import sys
from pathlib import Path

from fontTools import subset
from fontTools.ttLib import TTFont

FONTS = Path(__file__).resolve().parent.parent / "assets" / "fonts"

NOTO_UNICODES = [
    (0x0020, 0x02FF),  # Latin, Latin-1, Extended-A and -B, IPA, modifiers
    (0x0300, 0x036F),  # combining accents
    (0x0370, 0x03FF),  # Greek
    (0x0400, 0x052F),  # Cyrillic
    (0x1C80, 0x1C8F),  # Cyrillic Extended-C
    (0x1D00, 0x1DBF),  # phonetic extensions
    (0x1E00, 0x1FFF),  # Latin Extended Additional (Vietnamese), Greek Extended
    (0x2DE0, 0x2DFF),  # Cyrillic Extended-A
    (0xA640, 0xA69F),  # Cyrillic Extended-B
    (0x20AB, 0x20AB),  # đồng
    (0x20BD, 0x20BD),  # rouble
    (0x2116, 0x2116),  # numero
]

GREEK = (0x0370, 0x03FF)
COMBINING = (0x0300, 0x036F)

UNMAP = {
    "Nunito.ttf": [GREEK],
    "Caveat.ttf": [GREEK],
    "SpecialElite-Regular.ttf": [GREEK],
    "PatrickHand-Regular.ttf": [GREEK, COMBINING],
    "SpaceGrotesk-Variable.ttf": [GREEK, COMBINING],
}


def noto(source: Path) -> None:
    from fontTools.varLib import instancer

    unicodes = [c for lo, hi in NOTO_UNICODES for c in range(lo, hi + 1)]
    for style in ("", "-Italic"):
        font = TTFont(source / f"NotoSans{style}[wdth,wght].ttf")
        font = instancer.instantiateVariableFont(font, {"wdth": 100})
        # The subsetter needs the instance read back, not still in memory.
        buffer = io.BytesIO()
        font.save(buffer)
        buffer.seek(0)
        font = TTFont(buffer)
        options = subset.Options()
        options.layout_features = ["*"]
        subsetter = subset.Subsetter(options)
        subsetter.populate(unicodes=unicodes)
        subsetter.subset(font)
        font.save(FONTS / f"NotoSans{style}-Variable.ttf")


def unmap() -> None:
    for file, ranges in UNMAP.items():
        font = TTFont(FONTS / file)
        for table in font["cmap"].tables:
            for code in [c for c in table.cmap if any(lo <= c <= hi for lo, hi in ranges)]:
                del table.cmap[code]
        font.save(FONTS / file)


if __name__ == "__main__":
    {"noto": lambda: noto(Path(sys.argv[2])), "unmap": unmap}[sys.argv[1]]()
