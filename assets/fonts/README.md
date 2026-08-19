# Bundled fonts

Every bundled font is distributed under the SIL Open Font License 1.1.

## Offline PDF export

The app bundles `NotoSans-Regular.ttf` and `NotoNaskhArabic-Regular.ttf` only
for offline PDF generation. Both files come from the official archived
[`notofonts/noto-fonts`](https://github.com/notofonts/noto-fonts) repository and
are covered by `OFL.txt`.

- `NotoSans-Regular.ttf` renders English, Swedish, and Somali text.
- `NotoNaskhArabic-Regular.ttf` renders right-to-left Arabic text.

## Easy-reading story font

`AtkinsonHyperlegible-Regular.ttf` is the optional per-child easy-reading font
used for story prose in the reader and the parent review preview. Only the
regular weight is bundled, and only Latin-script story languages (English,
Swedish, Somali) use it; Arabic prose keeps the interface font because this face
has no Arabic script. PDF export is unaffected and still uses the Noto fonts.

- Source: [`googlefonts/atkinson-hyperlegible`](https://github.com/googlefonts/atkinson-hyperlegible),
  file `fonts/ttf/AtkinsonHyperlegible-Regular.ttf`.
- Designed for the Braille Institute of America to improve legibility for
  low-vision readers by making similar letters easier to tell apart.
- License: `OFL-AtkinsonHyperlegible.txt` (copyright 2020 Braille Institute of
  America, Inc.).
