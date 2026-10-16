# Mana iPhone launch assets checklist

## Scope and status

This checklist covers the App Store listing and public launch material for the iPhone app.
It complements `MANUAL.md`, which covers signing, device verification, upload, and submission.

Checked items mean an asset exists and was inspected. They do not mean owner approval or App Store acceptance.
No App Store Connect account was inspected. Name availability, uploads, and submission status remain unverified.

The existing package passes `python3 scripts/app-store-assets.py verify`.
The public homepage still promotes the Mac app. The support and privacy pages are published. The iPhone homepage link is intentionally deferred.

## 1. Positioning and brand

- [x] Existing Mana icon, blue hexagon, fonts, and visual direction.
- [x] Voice guide: `metadata/copy-voice.md`.
- [x] Approve the plain-language product sentence, proposed name, subtitle, and listing copy.
- [ ] Confirm `Mana — AI Usage` is available in App Store Connect.
- [ ] Confirm rights to use provider names, logos, and services publicly.

Suggested functional sentence:

> See your remaining Codex and OpenCode Go quotas, reset times, and widgets on your iPhone.

Keep “Save your mana” as the brand headline. Immediately explain the actual product.
Do not imply that Mana increases quotas, measures spend, supports every AI provider, or guarantees live widget updates.

## 2. App Store visual assets

### Existing assets

- [x] Opaque 1024 × 1024 icon: `icon/app-icon-1024.png`.
- [x] Four portrait screenshot designs at 1320 × 2868: `screenshots/iphone-6.9/`.
- [x] Four legacy exports at 1284 × 2778: `screenshots/iphone-6.5/`.
- [x] Original simulator captures and provenance: `screenshots/source/`.
- [x] Internal visual overview: `proposal/contact-sheet.jpg`.
- [x] Approve the full-size screenshot proposal and readability.
- [ ] Confirm that every screenshot matches the final distributed app.

### Missing or recommended additions

- [x] Capture a genuine Home Screen widget screenshot and compose its sample-labeled marketing panel.
- [ ] Capture a genuine Lock Screen widget screenshot; the simulator widget picker was not usable.
- [ ] Compose a Lock Screen marketing panel after capturing the real widget.
- [ ] Check the screenshot slots required by the actual App Store Connect record.
- [x] Export the medium Dynamic Island screenshot set at 1206 × 2622; confirm its slot in App Store Connect.

The retrieved Apple specification currently names the medium Dynamic Island iPhone display as required.
It also lists the existing 1320 × 2868 and 1284 × 2778 exports as accepted resolutions.
Its scaling notes do not unambiguously establish that this package fills every required slot.
Therefore, do not treat the older manual's “large set covers the slot” statement as final submission verification.

Recommended screenshot story:

1. **Save your mana.** Remaining AI quota in one clear view.
2. **Two spellbooks. One place.** Codex and OpenCode Go.
3. **Every limit. One look.** OpenCode Go quota windows.
4. **Your quotas. Close at hand.** Home Screen widgets.

The owner rejected the reset-countdown panel, including its clock artwork and “Tap a countdown” copy. It is not part of the current screenshot set.

Six panels are a recommendation, not an Apple minimum. Apple allows one to ten per device size.
No native iPad screenshot set is planned because the current app targets iPhone only.

## 3. App Store text and submission information

- [x] English listing source: `metadata/listing-en-US.json`.
- [x] Individual name, subtitle, promotional text, description, and keyword files.
- [x] Draft review notes: `metadata/app-review-notes.txt`.
- [x] Draft privacy worksheet: `metadata/privacy-worksheet.md`.
- [x] Approve the proposed English listing copy. Recheck claims against final App Store metadata and legal/provider permissions.
- [x] Keep provider and company names out of the keyword field; the current draft uses nonbrand terms.
- [ ] Complete a final audit of the keyword field against Apple's rules.
- [x] Set the published support URL: `https://mana.salsaparapizza.com/support.html`.
- [x] Set the published privacy URL: `https://mana.salsaparapizza.com/privacy.html`.
- [ ] Finalize categories, copyright, price, territories, and release mode.
- [ ] Complete privacy disclosures, age rating, encryption, content rights, and applicable trader status.
- [ ] Enter the App Review contact privately.
- [ ] Provide authorized access for reviewing live functionality; Demo alone does not verify it.
- [ ] Remove the pre-submission action paragraph from the final review notes after completing its actions.
- [ ] Claim accessibility features only after evaluating the distributed app.

Apple's current field limits include name and subtitle at 30 characters, promotional text at 170 characters,
description at 4000 characters, and keywords at 100 bytes.
“What’s New” is not available for the initial version; retain the draft for a later update if useful.

### Localization decision

The app supports English, German, Spanish, and French. The prepared store material is English only.

- [x] Launch language selected: English (U.S.) only. German, Spanish, and French listings are deferred.
- [ ] Approve the English listing and screenshot headlines.
- [ ] Confirm the English support and privacy pages match the released app.

Non-English store listings are not automatically required because the app supports those languages.

## 4. Public website, support, and privacy

Use the existing website: https://mana.salsaparapizza.com/.

- [ ] Add a distinct iPhone section with supported providers, screenshots, widgets, and iOS 18 compatibility.
- [ ] Keep Mac and iPhone provider coverage and downloads clearly separate.
- [ ] Explain that provider accounts and service access are separate from Mana.
- [x] Publish and verify the support page at `https://mana.salsaparapizza.com/support.html`. Support uses the public Mana GitHub issue tracker.
- [ ] Add setup instructions for Codex approval, OpenCode Go keys, and installing widgets.
- [ ] Add troubleshooting for stale quotas, failed sign-in, and delayed widget updates.
- [x] Publish the current privacy policy at `https://mana.salsaparapizza.com/privacy.html`. Recheck it against the final distributed app before submission.
- [x] Add a privacy-policy link in the current app source; verify it in the distribution build.
- [x] Confirm the marketing, support, and privacy URLs work over HTTPS.
- [ ] After public release, replace prototype messaging and add the verified App Store link and official badge.
- [ ] Update `docs/llms.txt` and the website social preview when public copy changes.

Do not claim “nothing leaves your phone.” Mana makes authenticated requests to provider services.
Do not copy the Mac credential-storage description into the iPhone policy; their storage implementations differ.

## 5. Public launch kit — recommended, not submission requirements

### Existing

- [x] Proposed iPhone social card at 1200 × 630: `proposal/social-preview.jpg`.
- [x] Reusable product icon and screenshot artwork.

### Prepare

- [ ] Prepare X and LinkedIn launch posts with a verified App Store link.
- [ ] Prepare a longer website announcement covering the problem, supported providers, widgets, setup, and limitations.
- [ ] A captioned product demo for social posts and the website; no credentials or personal account data.
- [ ] Prepare social crops for the selected X and LinkedIn channels; avoid generating unused formats.
- [ ] A lightweight press folder with the icon, clean screenshots, product facts, and creator contact.
- [ ] A GitHub release/README update that distinguishes App Store iPhone installation from Mac installation.
- [ ] A pinned support or known-issues note for launch.

Suggested demo sequence: open quota dashboard → inspect reset time → show Home Screen widget → show Lock Screen widget.
Avoid showing keys or approval codes. Use visibly disclosed synthetic data when demonstrating sample accounts.

## 6. Optional channel-specific assets

Prepare these only if that channel is part of the launch:

- [ ] App Store preview video, following Apple's separate preview specifications.
- [ ] Product Hunt gallery, tagline, maker introduction, and launch comments.
- [ ] Newsletter/email announcement, reviewed before sending.
- [ ] Media outreach pitch and tailored product images.
- [ ] Localized social copy.
- [ ] Additional App Store product-page variants or paid-ad creative.

Do not block submission on these assets. A social demo and an App Store preview are different deliverables.

## 7. Release blockers — not marketing assets

A completed asset checklist does not establish release readiness. Keep these gates in `MANUAL.md`:

- [ ] Verify public provider access and permissions. These are not confirmed yet.
- [x] Verify live Codex and OpenCode Go access on a signed iPhone. Owner reports using the app successfully for several days.
- [x] Owner confirms app/widget Keychain and App Group behavior, disconnect, account replacement, cache handling, offline/stale states, and widgets are technically verified.
- [x] Required-reason privacy manifests are present in the current app and widget source; inspect them in the distribution archive.
- [ ] Create and validate the App Store distribution archive. The last local inspection found only development and unsigned archives.
- [ ] Install through TestFlight and confirm the distributed build; this is a release pipeline step, not outstanding feature validation.
- [ ] Obtain explicit authorization before TestFlight upload or App Store submission.

## Similar material already available

- Mana submission checklist: `app-store-release-prep/MANUAL.md`.
- Mana asset verification: `app-store-release-prep/verification/FINAL-CHECKS.md`.
- Related local example: `../standing/app-store-release-prep/MANUAL.md`, from this repository's root.

Use Standing Desk as a structural example, not a source for privacy answers or provider-access assumptions.

## References checked

- Apple screenshot specifications: https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/
- Apple listing fields and review information: https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/
- Public Mana website: https://mana.salsaparapizza.com/

## Verification commands

```sh
python3 scripts/app-store-assets.py verify
git diff --check
```

These check the prepared asset package and whitespace. They do not validate App Store Connect requirements or live app behavior.
