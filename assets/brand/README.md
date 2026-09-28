# Star hero brand

The transparent `hero_mascot.png` is the source for the app logo, phone icons,
favicon and splash screens. Generated with the built-in imagegen tool. No
external artwork, child photographs or runtime image-generation dependency.

Prompt used:

> A polished 3D clay-toy mascot for a children's personalized storybook app:
> a smiling golden-yellow five-point star hero with a flowing lilac-purple cape,
> emerging above a clearly recognizable thick open storybook with creamy curved
> pages, a teal cover and coral bookmark. Soft matte vinyl, rounded shapes,
> upper-left studio lighting, lavender rim light, bold simple silhouette. One
> centered emblem on a genuinely transparent square background. No text,
> candle, border, confetti or background tile.

Regenerate platform assets using the commands in `docs/CODEBASE.md`.
The opaque icon uses the app's night background. Android adaptive and PWA
maskable versions reserve extra space for launcher cropping. The monochrome
Android icon uses the same mascot silhouette. The 128px transparent logo is
bundled for the app's drawer and desktop rail, where its frame and glow follow
the active profile accent; full-resolution source art is
not bundled in the Flutter asset manifest.
