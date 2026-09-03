# Bundled fonts

Every bundled font is distributed under the SIL Open Font License 1.1.

## Interface typeface

`Outfit-Variable.ttf` is the typeface the application chrome speaks in:
headings, labels, buttons, chips, and navigation, on every platform. It is
bundled, never downloaded at runtime, and no font package is used.

- Source: [`google/fonts`](https://github.com/google/fonts), file
  `ofl/outfit/Outfit[wght].ttf`, upstream
  [`Outfitio/Outfit-Fonts`](https://github.com/Outfitio/Outfit-Fonts).
- Renamed on the way in only because Flutter asset paths and square brackets
  do not mix. It is the unmodified upstream variable font.
- License: `OFL-Outfit.txt` (copyright 2021 The Outfit Project Authors).
- One `wght` axis, 100–900, whose **default instance is 100 (Thin)**. The
  shared theme therefore pins the axis with `fontVariations` on every style it
  builds instead of relying on `fontWeight` alone; a style that only asked for
  a weight would render hairline-thin.
- Latin only: it has no Arabic script. The interface text theme falls back to
  `NotoNaskhArabic` for the Arabic locale, decided in one place —
  `interfaceFontFamilyFor` in `lib/app/app_theme.dart` — following the same
  script rule story prose already uses for the easy-reading font.

`NotoNaskhArabic-Regular.ttf` therefore has two jobs: the Arabic body face of
an exported book, and the Arabic interface face. Only the regular weight is
bundled, so Arabic chrome carries less weight contrast than Latin chrome does.

## Offline PDF export

The app bundles `NotoSans-Regular.ttf` and `NotoNaskhArabic-Regular.ttf` only
for offline PDF generation. Both files come from the official archived
[`notofonts/noto-fonts`](https://github.com/notofonts/noto-fonts) repository and
are covered by `OFL.txt`.

- `NotoSans-Regular.ttf` renders English, Swedish, and Somali text.
- `NotoNaskhArabic-Regular.ttf` renders right-to-left Arabic text.

Both stay the **body** faces of an exported book: story prose, page numbers,
and the small print. Titles and headings use the display faces below.

## Storybook display faces

An exported book should look like a picture book, so titles, the dedication,
and the page badges are set in a rounded storybook display face rather than
in the body font. Two faces are bundled and one is selected per story
language:

- `Baloo2-Variable.ttf` renders titles and headings for English, Swedish, and
  Somali. Rounded, friendly, and heavy enough to read as a cover title.
  - Source: [`google/fonts`](https://github.com/google/fonts), file
    `ofl/baloo2/Baloo2[wght].ttf`, upstream
    [`EkType/Baloo2`](https://github.com/EkType/Baloo2).
  - Renamed on the way in only because Flutter asset paths and square
    brackets do not mix. It is the unmodified upstream variable font; the PDF
    renderer reads its default instance, which is the regular weight.
  - License: `OFL-Baloo2.txt` (copyright 2019 The Baloo 2 Project Authors).
  - Verified coverage: every Latin letter the four languages need, including
    Swedish `å ä ö Å Ä Ö`, plus the punctuation and digits the export prints.
- `Amiri-Bold.ttf` renders titles and headings for Arabic.
  - Source: [`google/fonts`](https://github.com/google/fonts), file
    `ofl/amiri/Amiri-Bold.ttf`, upstream
    [`aliftype/amiri`](https://github.com/aliftype/amiri).
  - License: `OFL-Amiri.txt` (copyright 2010–2022 The Amiri Project Authors).
  - Verified coverage: every glyph the shaped Arabic strings of an exported
    book resolve to, presentation forms included.

### Why not one family for both scripts

The obvious choice was one playful family covering both scripts — Baloo 2 for
Latin with its sibling Baloo Bhaijaan 2 for Arabic. It does not work here, and
the reason is the renderer rather than the font.

The `pdf` package shapes Arabic itself: it runs the text through the `bidi`
package, which converts joined letters into **Arabic Presentation Forms-B**
code points (`U+FE70`–`U+FEFF`), and then looks those code points up in the
font's `cmap`. A font that only supports Arabic through modern OpenType
shaping features has no such code points, and every joined letter comes out
blank. Measured against the exact strings this export prints:

| Font | Missing shaped glyphs |
| --- | --- |
| `NotoNaskhArabic-Regular` (body) | none |
| `Amiri-Bold` | none |
| Baloo Bhaijaan 2 | 44 — effectively every joined form |
| Lalezar, Rakkas, Almarai, Tajawal, Mirza, Katibeh, Vibes, Blaka | 1 (`U+FEF1`, isolated yeh — which the very common word `الذي` ends in) |

Amiri Bold was the only OFL Arabic display face tested that covers the whole
set, so it is the Arabic title face: warm, book-like, and heavy enough to
carry a cover. It is a Naskh rather than a rounded face, so the pairing with
Baloo 2 is a considered compromise, not a perfect match.

`test/core/export/story_pdf_fonts_test.dart` asserts this coverage against the
real font files, so a future font swap that would print blanks fails the
suite instead of shipping.

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

## Story prose serif

`Newsreader-Variable.ttf` is the book-like Latin-script face used for story
prose in the reader and the parent review preview when the child's easy-reading
setting is off. Arabic prose keeps `NotoNaskhArabic`, and PDF export keeps its
existing Noto body fonts.

- Source: [`google/fonts`](https://github.com/google/fonts), file
  `ofl/newsreader/Newsreader[opsz,wght].ttf`, upstream
  [`productiontype/Newsreader`](https://github.com/productiontype/Newsreader).
- Renamed on the way in only because Flutter asset paths and square brackets
  do not mix. It is the unmodified upstream variable font.
- The `opsz` axis spans 6–72 and `wght` spans 200–800. Its default instance is
  16pt regular at weight 400, so the resolver does not pin the weight axis.
- License: `OFL-Newsreader.txt` (copyright 2020 The Newsreader Project Authors).
