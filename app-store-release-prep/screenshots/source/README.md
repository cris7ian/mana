# Source screenshots

These are unmodified XCTest captures from a dedicated iPhone simulator. The app runs with `--ui-testing --demo`; dark captures also use `--demo-dark`.

- No real account, provider response, or credential appears in the images.
- The visible percentages and reset countdowns are synthetic demo values.
- Demo labels remain present in every screen and export.
- `provenance.json` records the original file hashes.
- `../manifest.json` records the composed export hashes.

From the repository root, reproduce with `zsh scripts/capture-app-store.sh`. Recompose with `python3 scripts/app-store-assets.py render`.

The phone framing and marketing text sit outside the app captures. The renderer resizes and rounds display corners. Slides 2 and 3 enlarge complete provider-card crops, including their sample-data labels. It does not reconstruct the interface or replace its text.

Crop coordinates are recorded in `screenshots/manifest.json` as `[left, top, right, bottom]` on the original 1320 × 2868 source. Review these coordinates after any UI change.

Source captures are not evidence of live provider access or a production-ready release.
