# Mana iPhone release checklist

**Status: proposal approved; product technical validation is complete per owner.** The owner reports successful daily use of the iPhone app and confirms no technical validation remains. The support and privacy pages are published. App Store Connect setup, distribution signing/archive, TestFlight, and submission remain. Public provider permission is not confirmed.

## 1. Approve the proposal

- [x] Review and approve `proposal/contact-sheet.jpg`, the full-size screenshots, and proposed listing copy.
- [x] Approve the proposed free price and categories.
- [x] Approve the proposed name, “Mana — AI Usage.”
- [ ] Check name availability in App Store Connect.

## 2. Close the app's existing release gates

See `ios/README.md`. The owner confirms product technical validation is complete and reports successful daily use. No further feature-validation work is pending.

- [ ] Obtain or confirm permission for public third-party provider access and branding. This is an authorization gate, not a functionality test.
- [x] Codex browser approval and usage retrieval on a signed iPhone.
- [x] OpenCode Go usage with an authorized account on a signed iPhone.
- [x] App/widget App Group and Keychain sharing.
- [x] Disconnect, account replacement, cache protection, and backup behavior.
- [x] Foreground refresh, offline/stale states, and independent provider failures.
- [x] Home Screen and Lock Screen widget functionality.
- [x] Browser return and expired approval-code behavior.
- [x] Add the privacy-policy link in the current app source.
- [ ] Recheck the approved privacy disclosure and links in the App Store distribution build.

## 3. Confirm listing URLs

Use the existing website at `https://mana.salsaparapizza.com/`. The support and privacy pages are published at `/support.html` and `/privacy.html`. Their HTTPS URLs return HTTP 200 and are recorded in `metadata/listing-en-US.json`.

- [x] Confirm the marketing website is reachable over HTTPS.
- [x] Publish and verify the support URL: `https://mana.salsaparapizza.com/support.html`.
- [x] Publish and verify the privacy URL: `https://mana.salsaparapizza.com/privacy.html`.
- [ ] Recheck the privacy policy against the final distributed app before submission.

## 4. Verify and archive

The last local archive inspection found Apple Development and unsigned archives, but no Apple Distribution identity or App Store profiles. Recheck current signing access. Only a distribution-signed archive can be uploaded.

- [x] Complete product test suites and asset checks for the current preparation. The owner confirms technical validation is complete.
- [ ] Rebuild and archive the exact App Store submission source.
- [ ] Confirm the build number has not already been uploaded.
- [ ] Confirm the App Store Connect app record and registered app/widget identifiers, App Group, and shared Keychain access.
- [ ] Select automatic signing for app and widget targets.
- [ ] Archive `ManaIOS` for a generic iOS device using Release configuration.
- [ ] Inspect app and extension identifiers, versions, entitlements, and privacy manifests.
- [ ] Validate the archive in Xcode Organizer.
- [ ] Resolve every validation warning.

No archive is included in this asset package.

## 5. Fill App Store Connect

- [ ] Create or select the correct iOS app record and bundle ID.
- [ ] Paste the approved individual text fields from `metadata/`.
- [x] Use the published support and privacy URLs in `metadata/listing-en-US.json`.
- [ ] Complete privacy, age rating, encryption, content rights, and trader status accurately.
- [ ] Set owner-approved price, territories, and release mode.
- [ ] Enter review contact details privately.
- [ ] Provide authorized review access where Apple requires it.
- [ ] Remove the preparation paragraph from the final review notes after completing its actions.

## 6. Upload and review the distributed build

- [ ] Upload the validated archive through Xcode Organizer.
- [ ] Wait for processing and attach the build to the correct version.
- [ ] Install the build through TestFlight on a real iPhone.
- [ ] Run the release smoke check on the distributed build; product technical validation is otherwise complete.
- [ ] Confirm screenshots still match the distributed build.
- [ ] Upload `screenshots/iphone-dynamic-island-medium/` in numeric order to the current required medium Dynamic Island slot.
- [ ] Add `screenshots/iphone-6.9/` to the large Dynamic Island slot.
- [ ] Use the 6.5-inch set only if App Store Connect requires that slot.
- [ ] Submit only after all release gates pass and the owner authorizes submission.

All three screenshot sets meet Apple’s listed portrait dimensions. The current specification requires at least one medium Dynamic Island screenshot; the package includes 1206 × 2622 exports for that slot and 1320 × 2868 for the large slot. The 1284 × 2778 legacy set is optional. Verify the live App Store Connect slot labels at upload time. No iPad set is included because the current app targets iPhone only. Source: https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/ (checked 2026-10-06).

## 7. After approval

- [ ] Check the public listing and screenshot order.
- [ ] Add the verified App Store link to the existing website when requested.
- [ ] Install the App Store build and repeat the critical device checks.
