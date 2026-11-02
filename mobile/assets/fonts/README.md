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
License 1.1, [OFL-NotoSans.txt](OFL-NotoSans.txt)) draws the Greek, Cyrillic
and Vietnamese letters that DM Sans, Space Grotesk, Patrick Hand and Playfair
Display lack. It is cut down to those letters, at normal width, keeping the
weight axis:

```sh
python -m fontTools.varLib.instancer "NotoSans[wdth,wght].ttf" wdth=100 -o inst.ttf
python -m fontTools.subset inst.ttf --layout-features='*' \
  --unicodes=U+0300-036F,U+0370-03FF,U+1F00-1FFF,U+0400-052F,U+1C80-1C8F,U+2DE0-2DFF,U+A640-A69F,U+0180-024F,U+1E00-1EFF,U+20AB,U+20BD,U+2116 \
  --output-file=NotoSans-Variable.ttf
```

The same for `NotoSans-Italic[wdth,wght].ttf`, from google/fonts.
