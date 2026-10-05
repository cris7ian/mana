# Mana iPhone release checklist

**Status: assets prepared; public release not verified.** No upload, submission, account configuration, or deployment was performed.

## 1. Approve the proposal

- [ ] Review `proposal/contact-sheet.jpg` and the full-size screenshots.
- [ ] Approve the wording in `metadata/listing-en-US.json`.
- [ ] Confirm the proposed free price and categories.
- [ ] Confirm “Mana — AI Usage” is available in App Store Connect.

## 2. Close the app's existing release gates

See `ios/README.md`. Synthetic captures do not close these gates.

- [ ] Obtain or confirm permission for public third-party provider access and branding.
- [ ] Verify Codex browser approval and usage retrieval on a signed iPhone.
- [ ] Verify OpenCode Go usage with an authorized account on a signed iPhone.
- [ ] Verify app/widget App Group and Keychain sharing on a signed iPhone.
- [ ] Verify disconnect removes credentials and cached values from both app and widgets.
- [ ] Verify cache protection, backup exclusion, and account replacement behavior.
- [ ] Verify foreground refresh, offline/stale states, and independent provider failures.
- [ ] Verify Home Screen and Lock Screen widgets on the distributed build.
- [ ] Verify returning from browser approval and expired approval codes.
- [ ] Review final privacy disclosure and required-reason API manifests.
- [ ] Add a reachable privacy-policy link inside the released app.

## 3. Confirm listing URLs

Use the existing website at `https://mana.salsaparapizza.com/`. Its source is in `docs/`; no separate website is included in this package.

- [ ] Confirm the existing website is suitable for the listing's marketing URL.
- [ ] Confirm a reachable support URL.
- [ ] Confirm a published privacy policy that matches the distributed app.
- [ ] Verify the final URLs over HTTPS before entering them in App Store Connect.

Support and privacy-policy URLs remain unassigned in the listing draft. Website changes are outside this asset package.

## 4. Verify and archive

- [ ] Run all checks in `verification/FINAL-CHECKS.md` against the final source.
- [ ] Confirm the build number has not already been uploaded.
- [ ] Register app and widget identifiers, App Group, and shared Keychain access.
- [ ] Select automatic signing for app and widget targets.
- [ ] Archive `ManaIOS` for a generic iOS device using Release configuration.
- [ ] Inspect app and extension identifiers, versions, entitlements, and privacy manifests.
- [ ] Validate the archive in Xcode Organizer.
- [ ] Resolve every validation warning.

No archive is included in this asset package.

## 5. Fill App Store Connect

- [ ] Create or select the correct iOS app record and bundle ID.
- [ ] Paste the individual text files from `metadata/`.
- [ ] Set verified public URLs.
- [ ] Complete privacy, age rating, encryption, content rights, and trader status accurately.
- [ ] Set owner-approved price, territories, and release mode.
- [ ] Enter review contact details privately.
- [ ] Provide authorized review access where Apple requires it.
- [ ] Remove the preparation paragraph from the final review notes after completing its actions.

## 6. Upload and review the distributed build

- [ ] Upload the validated archive through Xcode Organizer.
- [ ] Wait for processing and attach the build to the correct version.
- [ ] Install the build through TestFlight on a real iPhone.
- [ ] Repeat live-provider, credential, stale-state, and widget checks.
- [ ] Confirm screenshots still match the distributed build.
- [ ] Upload `screenshots/iphone-6.9/` in numeric order.
- [ ] Use the 6.5-inch set only if App Store Connect requires that slot.
- [ ] Submit only after all release gates pass and the owner authorizes submission.

Both screenshot sets meet Apple's listed portrait dimensions. The 6.9-inch set covers the large iPhone slot; Apple can scale it for smaller devices. No iPad set is included because the current app targets iPhone only.

## 7. After approval

- [ ] Check the public listing and screenshot order.
- [ ] Add the verified App Store link to the existing website when requested.
- [ ] Install the App Store build and repeat the critical device checks.
