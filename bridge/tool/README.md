# Hero likeness check

`likeness_check.dart` makes the by-eye comparison that proves one Child
profile's Hero remains recognizably the same drawn child across two Stories.
It uses an isolated temporary Master library, so it never changes the family's
real library.

From `bridge/`, run the family's usual comparison with:

```sh
dart run tool/likeness_check.dart --photo D:/Family/likeness-test.png --config-from bridge_config.json --out D:/Family/likeness-check --language en --hero-name Sami --gender boy
```

Open `D:/Family/likeness-check/compare.html`. Each page of the first Story is
beside the matching page of the second. Look for the same recognizable drawn
Hero, including the recurring outfit and prop, rather than photographic detail.

The run leaves `D:/Family/likeness-check/bridge-config.json` intentionally.
For Step 5 tuning, edit its `ipAdapterWeight`, `referenceDenoise`, LoRA values,
or checkpoint, then run the same command again and compare the new page.
