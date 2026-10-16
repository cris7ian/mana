# Product-first export verification — 2026-10-06

- Captured seven original app PNGs through two passing XCTest screenshot tests on the dedicated Mana App Store Assets iPhone 17 Pro Max simulator, iOS 26.5.
- Capture evidence: `build/app-store-capture-20261006-233622.xcresult` and `build/app-store-attachments-20261006-233622/manifest.json`.
- All app images show genuine native UI with synthetic Demo data, not connected-account evidence.
- The four product panels explain remaining quotas, Codex/OpenCode Go coverage, reset countdowns, and OpenCode Go quota windows. No storage marketing panel is in the upload directories.
- Export sizes: medium Dynamic Island 1206 × 2622, large Dynamic Island 1320 × 2868, and optional legacy large Face ID 1284 × 2778.
- Apple’s current screenshot requirements were retrieved from https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/ . The current required iPhone slot is medium Dynamic Island. Verify slot labels again at upload time.
- Metadata checks passed: name 15/30 characters, subtitle 30/30, promotional text 129/170, description 1084/4000, keywords 96/100 UTF-8 bytes, release notes 127/4000.
- Source/export SHA-256 checks, PNG dimensions, opaque RGB exports, generated text consistency, icon dimensions, supporting art dimensions, and absence of a separate website passed.
- `zsh -n scripts/capture-app-store.sh` and `git diff --check` passed at the export recheck.
- Full application suites and signed-device/provider tests are outside this asset-verification report. See the repository-wide release evidence separately.

## Archive

Run `python3 scripts/app-store-assets.py render`, `verify`, then `package`. Packaging re-runs asset verification, checks ZIP CRCs and every included file’s exact original bytes, and creates `build/mana-iphone-app-store-assets.zip` plus its SHA-256 sidecar. Hidden files and superseded upload panels are excluded. The archive contains PNG originals, full-resolution exports, both PNG/JPEG contact sheets, copy-ready metadata, the icon, and asset documentation; it is not an installable app or a distribution archive.

## Widget capture evidence

The final Home Screen widget capture was exported from `build/widget-exploration-7.xcresult` and visually inspected: the real installed native overview widget displays both providers and a visible `DEMO · SAMPLE` label. Its full native capture is preserved in `screenshots/source/home-widget.png` with SHA-256 provenance. The five product panels are exported in three sizes, for 15 opaque RGB PNGs. Backgrounds translate the website’s blue square-tile field, diagonal wind bands, torch glows, and luminous mana motes into static artwork; native app and widget content is unchanged.

The Lock Screen exploration reached customization only; no installed Mana Lock Screen widget screenshot is included or claimed. Simulator widget evidence does not establish signed-device Keychain sharing or real-account updates.

The final `render`, `verify`, `package`, and whitespace checks passed. ZIP CRCs and byte-for-byte contents passed for every included file.
