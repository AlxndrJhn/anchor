# Note fonts

The fonts offered for text in notes, bundled so they work offline. Each is
stored on text as the `font` value in brackets.

| Font | Value | Licence |
|---|---|---|
| [Comic Neue](https://github.com/crozynski/comicneue) (Comic Sans MS is used where installed) | `comic` | SIL Open Font License 1.1 ([OFL-ComicNeue.txt](OFL-ComicNeue.txt)) |
| [Caveat](https://github.com/googlefonts/caveat) | `handwriting` | SIL Open Font License 1.1 |
| [Special Elite](https://fonts.google.com/specimen/Special+Elite) | `typewriter` | Apache License 2.0 |
| [Nunito](https://github.com/googlefonts/nunito) | `rounded` | SIL Open Font License 1.1 |
| [Roboto Slab](https://github.com/googlefonts/robotoslab) | `slab` | Apache License 2.0 |
| [Permanent Marker](https://fonts.google.com/specimen/Permanent+Marker) | `marker` | Apache License 2.0 |

Taken from [google/fonts](https://github.com/google/fonts).

## Fallback

[Noto Sans](https://github.com/notofonts/latin-greek-cyrillic) (SIL Open Font
License 1.1, [OFL-NotoSans.txt](OFL-NotoSans.txt)) draws the letters the other
fonts lack: Greek, Cyrillic, Vietnamese, IPA and the rarer Latin letters. It
is cut down to Latin, Greek and Cyrillic, at normal width, keeping the weight
axis. From the `ofl/notosans` folder of google/fonts:

```sh
python tool/fonts.py noto path/to/google/fonts/ofl/notosans
```

Some fonts have a few characters they draw badly next to the fallback: a
handful of Greek letters (Nunito's Σ is a summation sign), or combining
accents they cannot place on letters (Space Grotesk and Patrick Hand with
Yoruba's ẹ̀). `tool/fonts.py unmap` takes those out of the fonts' character
maps, so the whole word or letter falls back to Noto Sans; the glyphs stay.
Run it again on a font file that is updated. Playfair Display is left as it
is: its licence reserves the name for unmodified copies.
