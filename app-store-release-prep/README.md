# Mana iPhone App Store assets

Prepared on 2026-10-05. **A release-asset proposal, not a submitted or verified public release.**

## Open the proposal

Open [`proposal/contact-sheet.jpg`](proposal/contact-sheet.jpg) for the visual overview, then review the full-size screenshot exports.

**Direction: A little magic. A lot of clarity.**

Mana's blue hexagon, night-sky colors, and spellbook language meet large, readable headlines and straightforward product explanations. Four screenshots tell one story:

1. **Save your mana.** Your AI usage. One clear view.
2. **Two spellbooks. One place.** Codex and OpenCode Go.
3. **Know when you’re back.** Quota reset countdowns.
4. **Your keys. Your iPhone.** Device-only credentials and latest usage.

All app screens are genuine simulator captures. Quotas are synthetic and remain visibly labeled. Screens were not reconstructed or retouched.

## Package

| Path | Contents |
| --- | --- |
| `proposal/` | Contact sheet and 1200 × 630 social card |
| `screenshots/iphone-6.9/` | Four opaque PNGs at 1320 × 2868 |
| `screenshots/iphone-6.5/` | Four opaque PNGs at 1284 × 2778; optional legacy set |
| `screenshots/source/` | Seven original captures and SHA-256 provenance |
| `screenshots/manifest.json` | Export dimensions, copy, and SHA-256 hashes |
| `icon/` | The existing app icon, exported as an opaque 1024 × 1024 PNG |
| `metadata/` | Listing source, copy-ready text fields, review notes, voice guide, privacy worksheet |
| `MANUAL.md` | Upload procedure and open release gates |
| `verification/FINAL-CHECKS.md` | Asset and release verification commands |

## Reproduce

On macOS, with Xcode 26, an iOS 26 or later simulator runtime, Python 3, Pillow, and numpy:

```sh
# Capture only synthetic data in a dedicated simulator, then compose the assets.
zsh scripts/capture-app-store.sh

# Recompose from the included captures after changing the layout or copy.
python3 scripts/app-store-assets.py render

# Check image formats, dimensions, metadata limits, and source/export hashes.
python3 scripts/app-store-assets.py verify
```

The sans-serif renderer uses macOS Arial. The decorative fonts already exist in `docs/assets/fonts/`, with their licenses.

Use the files directly from `app-store-release-prep/`. The folder contains App Store assets and documentation, not a separate website.

## Boundaries

- Prototype setup and behavior are documented in [`../ios/README.md`](../ios/README.md).
- The iPhone app supports Codex and OpenCode Go. Antigravity remains a Mac feature.
- This package does not alter the public Mac website or app authentication.
- Use the existing website at `https://mana.salsaparapizza.com/`; its source remains in `docs/`.
- Confirm the final support and privacy-policy URLs before submission.
- Provider permission, live sign-in, signed-device storage, widgets, and TestFlight remain release gates.
- No App Store Connect record, build upload, pricing change, submission, or public deployment was performed.
- No distribution archive is included. Asset preparation does not establish app release readiness.

Start with [`MANUAL.md`](MANUAL.md) before uploading anything.
