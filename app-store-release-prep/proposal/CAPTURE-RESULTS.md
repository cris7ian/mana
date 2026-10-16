# Final asset capture results

This report supersedes earlier four-panel capture evidence in `verification/ASSET-EXPORTS.md`.

## Capture evidence and current exports

The original simulator capture run produced five product-first panels. The owner later rejected the reset-countdown panel, including its clock artwork and “Tap a countdown” copy. The current renderer now produces four panels in three sizes: **12 opaque RGB PNG exports**.

- Sizes: **1206 × 2622**, **1320 × 2868**, and **1284 × 2778**.
- **Eight unmodified source PNGs** remain with SHA-256 provenance.
- PNG and JPEG image contact sheets: **1640 × 1200**.
- Social card: **1200 × 630**. App icon: **1024 × 1024**.
- Copy-ready English metadata: name 15/30, subtitle 30/30, promotional text 129/170, description 1084/4000, keywords **96/100 UTF-8 bytes**, release notes 127/4000.

## Original capture evidence

`build/app-store-capture-20261007-000222.xcresult` reports **3 passed, 0 failed, 0 skipped**. This evidence is unchanged; the current asset set only omits one composed panel.

1. `testCaptureDarkScreens()`
2. `testCaptureHomeWidget()`
3. `testCaptureLightScreens()`

Xcode exported eight captures to `build/app-store-attachments-20261007-000222/`. The importer copied their original bytes without modification.

The Home Screen overview widget is genuinely installed, not a gallery preview. Its original PNG shows `DEMO · SAMPLE`, Codex 72%/54%, and OpenCode Go 84%/62%/33%. The panel crops the complete native widget from the full source screenshot. No UI was reconstructed, recolored, or relabeled.

The capture runs only on the dedicated credential-free **Mana App Store Assets** simulator. App captures use isolated UI-test Demo. Widget capture uses normal shared Demo, without provider connections or real credentials.

## Visual inspection

The full-size panel files and both contact-sheet rows were visually inspected. Headline margins, complete native cards, sample labels, and quota windows are intact. Native dark-mode remaining values are less prominent than light-mode values; their original appearance was preserved rather than retouched.

## Honest limits

Lock Screen customization was reached. The iOS 26.5 simulator did not present a usable widget picker after Add Widgets; one attempt stalled for several minutes. Diagnostic PNGs remain under `build/widget-exploration-7-attachments/` and `build/widget-exploration-8-attachments/`, outside the deliverable ZIP. No Lock Screen screenshot was fabricated or exported.

An intermediate run failed while another agent's `AppInformation` test source was incomplete. A later build succeeded. Another exploratory gallery hierarchy query ended with signal kill; native coordinate taps subsequently installed the Home Screen widget successfully. The final focused capture suite passed.

Simulator Demo evidence does not establish provider permission, live access, signed-device widget behavior, credential sharing, or release readiness. No commit, push, upload, deployment, or submission was performed.

## Archive

Run `python3 scripts/app-store-assets.py package` to produce `build/mana-iphone-app-store-assets.zip` and its SHA-256 sidecar. Packaging first verifies assets, then checks ZIP CRCs, exact membership, and archived bytes against originals. Superseded `04-your-keys.png` files are archived outside upload directories in `build/superseded-app-store-assets/`.
