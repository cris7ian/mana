# Mana iPhone App Store assets

Updated on 2026-10-06. **A release-asset proposal, not a submitted or verified public release.**

## Open the proposal

Open [`proposal/contact-sheet.jpg`](proposal/contact-sheet.jpg) for the visual overview, then review the full-size screenshot exports. [`proposal/CAPTURE-RESULTS.md`](proposal/CAPTURE-RESULTS.md) records the original capture evidence. The countdown panel was removed from the current four-panel proposal at the owner's request.

**Direction: A little magic. A lot of clarity.**

Mana's blue hexagon, night-sky colors, and spellbook language meet large, readable headlines and straightforward product explanations. Product-first screenshots tell one story:

1. **Save your mana.** Your AI usage. One clear view.
2. **Two spellbooks. One place.** Codex and OpenCode Go.
3. **Every limit. One look.** Five-hour, weekly, and monthly OpenCode Go quotas.
4. **Your quotas. Close at hand.** A genuine installed Home Screen overview widget.

All app screens are genuine simulator captures. Quotas are synthetic and remain visibly labeled. Screens were not reconstructed or retouched.

## Package

| Path | Contents |
| --- | --- |
| `proposal/` | Contact sheet and 1200 × 630 social card |
| `screenshots/iphone-dynamic-island-medium/` | Four opaque PNGs at 1206 × 2622, current required medium Dynamic Island slot |
| `screenshots/iphone-6.9/` | Four opaque PNGs at 1320 × 2868 |
| `screenshots/iphone-6.5/` | Four opaque PNGs at 1284 × 2778; optional legacy set |
| `screenshots/source/` | Eight original captures and SHA-256 provenance |
| `screenshots/manifest.json` | Export dimensions, copy, and SHA-256 hashes |
| `icon/` | The existing app icon, exported as an opaque 1024 × 1024 PNG |
| `metadata/` | Listing source, copy-ready text fields, review notes, voice guide, privacy worksheet |
| `MANUAL.md` | Upload procedure and open release gates |
| `verification/FINAL-CHECKS.md` | Asset and release verification commands |

## Reproduce

On macOS, with Xcode 26, an iOS 26 or later simulator runtime, Python 3, Pillow, and numpy:

```sh
# From the repository root: rebuild app, capture demo UI/widget, render, verify, and ZIP.
zsh scripts/capture-app-store.sh

# Only for poster backgrounds or marketing copy; reuses existing native captures.
zsh scripts/capture-app-store.sh --reuse-captures

# Show usage.
zsh scripts/capture-app-store.sh --help
```

Always use the default command after app UI changes. `--reuse-captures` does not rebuild or photograph the app.
The command stops on failed tests or verification; do not deliver an older ZIP after a failed run.
Evidence is saved to a unique `build/app-store-capture-*.xcresult` path on each run.
The final ZIP and SHA-256 sidecar are written to `build/mana-iphone-app-store-assets.zip` and `.zip.sha256`.
The script uses only the dedicated `Mana App Store Assets` simulator; never store credentials there.

For individual stages, use `python3 scripts/app-store-assets.py render`, `verify`, or `package`.
`package` verifies dimensions, metadata, hashes, archive membership, CRCs, and exact archived bytes.

The sans-serif renderer uses macOS Arial. The decorative fonts already exist in `docs/assets/fonts/`, with their licenses.

Use the files directly from `app-store-release-prep/`.

The ZIP includes full-resolution PNG originals and exports, the contact sheet, copy-ready metadata, icon, and documentation. It is an asset archive, not an installable app. The folder contains App Store assets and documentation, not a separate website.

The verified ZIP is `../build/mana-iphone-app-store-assets.zip`. It excludes hidden files, test logs, and obsolete panels. Its CRCs, exact file membership, and original bytes are verified.

Apple’s current [screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/) require the medium Dynamic Island iPhone slot. The prepared medium exports are 1206 × 2622. Large exports remain optional additional sets.

App captures use `--ui-testing --demo`. Widget capture uses normal `--demo` on the dedicated credential-free simulator, because isolated UI tests do not persist shared Demo state. Never run widget capture on an account-bearing simulator.

The original Home Screen capture includes the UI-test runner icon. The marketing panel crops the complete installed native widget, including `DEMO · SAMPLE`; it is not a gallery preview. Superseded `04-your-keys.png` files were safely archived in `../build/superseded-app-store-assets/`, outside upload directories and the ZIP.

## Widget capture limits

The Home Screen widget is genuinely installed and captured. Lock Screen customization was reached, but the iOS 26.5 simulator did not present a usable widget picker after tapping Add Widgets. One attempt stalled for several minutes. No Lock Screen panel was fabricated or exported. Diagnostic captures remain in `../build/widget-exploration-7-attachments/` and `../build/widget-exploration-8-attachments/`, outside the ZIP. The owner reports technical widget validation on the app; capture a Lock Screen marketing panel only if wanted.

## Boundaries

- Prototype setup and behavior are documented in [`../ios/README.md`](../ios/README.md).
- The iPhone app supports Codex and OpenCode Go. Antigravity remains a Mac feature.
- This package does not alter the public Mac website or app authentication.
- Use the existing website at `https://mana.salsaparapizza.com/`; its source remains in `docs/`.
- Support and privacy URLs are published and recorded in `metadata/listing-en-US.json`.
- The owner reports successful daily use and confirms technical validation is complete. Public provider permission, distribution signing, App Store Connect setup, TestFlight, and App Review remain.
- No App Store Connect record, iOS build upload, pricing change, or App Store submission was performed. The support and privacy pages are published; the iPhone homepage link remains deferred.
- No distribution archive is included. Asset preparation does not establish app release readiness.

Start with [`MANUAL.md`](MANUAL.md) before uploading anything.
