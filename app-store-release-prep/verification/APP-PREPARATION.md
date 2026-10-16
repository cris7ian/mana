# Mana iOS app preparation

**Historical report:** local app preparation verified on 6–7 October 2026 with Xcode 26.6, build 17F113. This snapshot predates the website publication and the owner's later report of successful daily use. See `../MANUAL.md` for current release status.

No App Store upload or submission occurred during this verification. No provider credentials or provider account files were read.

## Implemented

- Added native browser links in Settings, inside the Privacy section.
- Support destination: `https://mana.salsaparapizza.com/support.html`.
- Privacy destination: `https://mana.salsaparapizza.com/privacy.html`.
- Added English, German, Spanish, and French labels and accessibility hints.
- Kept Demo as the final settings control, above the creator footer.
- Added tests for exact HTTPS destinations and both bundled privacy manifests.
- Added rendered UI tests for all four languages and the largest accessibility text size.
- Added generated `PrivacyInfo.xcprivacy` files to app and widget synchronized source groups.
- Verified regeneration preserves the project and both manifests byte-for-byte.

The links use SwiftUI `Link`; tests verify destinations, labels, enabled state, and accessibility reachability.
At the time of this report, the pages were unpublished and returned HTTP 404. They have since been published and verified over HTTPS. Browser navigation in the final distribution build remains a release-pipeline check.

## Required-reason API audit

Apple references retrieved during preparation:

- https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api
- https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype
- https://developer.apple.com/documentation/bundleresources/privacy-manifest-files

Both executable bundles contain this declaration:

```xml
<key>NSPrivacyAccessedAPITypes</key>
<array>
  <dict>
    <key>NSPrivacyAccessedAPIType</key>
    <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
    <key>NSPrivacyAccessedAPITypeReasons</key>
    <array><string>1C8F.1</string></array>
  </dict>
</array>
```

Apple approves `1C8F.1` for defaults accessible only to members of the same App Group.
The app writes the Demo preference; the app and widget read that shared preference.
The suite is `group.com.salsaparapizza.mana.ios`.

Evidence:

| Source | Observed use |
| --- | --- |
| `ios/Mana/ManaIOSApp.swift` | Registers and reads `demoMode` in App Group defaults |
| `ios/Mana/MobileAppModel.swift` | Writes Demo changes to App Group defaults |
| `ios/Shared/WidgetSnapshot.swift` | Reads the shared Demo preference |
| `Packages/ManaCore/Sources/` | No directly listed required-reason API calls found |

`CA92.1` is not used: the preference is shared with an extension, not restricted to the app alone.

The audit covered Apple's file timestamp, boot time, disk space, active keyboard, and defaults categories.
No direct listed file timestamp, boot time, disk space, or active keyboard APIs were found in shipped iOS/shared/core source.
The macOS-only `systemUptime` and file-attribute calls are outside these iOS targets.
`ContinuousClock` implements local timeouts; it is not a directly listed required-reason API.
Cache freshness uses normalized snapshot dates, not filesystem timestamps.
File protection, permissions, advisory locks, and backup exclusion do not add observed required-reason categories.

`nm -u` inspection found `NSUserDefaults` in both archived executables.
It found no direct imports matching the other listed required-reason APIs.
Static inspection does not replace Apple's distribution validation.

The app links the first-party `ManaCore` package, which has no external package dependencies.
Archived dynamic dependencies are Apple system frameworks and Swift libraries.
No bundled telemetry, advertising, or third-party SDK was identified.
The resource-only ManaCore bundle uses no observed required-reason APIs.

**Privacy data-collection disclosure remains unresolved.**
These manifests declare required-reason APIs only; they do not claim “Data Not Collected”.
Provider processing, retention, linkage, and any applicable collected-data declarations need owner/provider confirmation.
App Store privacy answers and the public policy must match that decision before distribution.

## Verification results

Logs reside in `build/app-preparation/`.

| Check | Actual result | Evidence |
| --- | --- | --- |
| Focused pre-change iOS baseline | 56 unit tests; zero failures | `baseline-ios.log` |
| Red destination/config test | Build failed because `AppInformation` did not exist | `red-links.log` |
| Focused implementation check | 2 unit tests and 5 new UI tests; zero failures | `green-links.log` |
| Localization verification | 225 keys across en/de/es/fr; passed | `localizations.log` |
| ManaCore suite | 23 Swift Testing tests; passed | `core.log` |
| macOS suite | 22 tests; zero failures | `macos.log` |
| Full iOS verification script | 58 unit tests; 17 UI tests, one skipped; zero failures | `ios-full.log` |
| Final iOS unit rerun, including added widget manifest test | 59 tests; zero failures | `final-ios-unit.log` |
| Development Release archive | `ARCHIVE SUCCEEDED` | `signed-archive-attempt.log` |
| Unsigned Release archive | `ARCHIVE SUCCEEDED` | `unsigned-archive.log` |
| Archive property/resource/import inspection | Assertions passed for app and widget in both archives | `archive-inspection.json` |
| Development signature verification | `codesign --verify --deep --strict` passed | Direct local verification |

The full iOS run used `platform=iOS Simulator,name=iPhone 17 Pro`.
The skipped test was `ManaAppStoreScreenshotTests.testCaptureHomeWidget`.
It requires the separate credential-isolated asset simulator; the asset workstream owns that capture.
No baseline unit failures or implementation regressions were observed.
A full pre-change macOS/UI baseline was not run; do not infer broader baseline evidence.

Non-failing diagnostics included App Intents metadata extraction notices.
The macOS tests also emitted XCTest deployment-target linker warnings and OS `linkd.autoShortcut` connection messages.
These did not fail the suites. No claim is made that App Store validation warnings are resolved.

Result bundles:

- Full iOS: `build/ios/Logs/Test/Test-ManaIOS-2026.10.06_23-41-29-+0300.xcresult`.
- Final iOS unit: `build/app-preparation/ios/Logs/Test/Test-ManaIOS-2026.10.07_00-03-45-+0300.xcresult`.
- macOS: `/Users/cristian/Library/Developer/Xcode/DerivedData/Mana-grfxzipujksuxugdtxuiavcwamlt/Logs/Test/Test-Mana-2026.10.06_23-41-18-+0300.xcresult`.

## Archives and signing

Local archives:

1. `build/app-preparation/Mana-DEVELOPMENT-NOT-FOR-UPLOAD.xcarchive`.
2. `build/app-preparation/Mana-UNSIGNED-NOT-FOR-UPLOAD.xcarchive`.

Both contain an arm64 Release app and embedded widget, plus their privacy manifests.
Both use version `1.0.0`, build `1`, minimum iOS `18.0`, and iPhone-only device family `[1]`.
Build-number availability in App Store Connect was not checked.

| Bundle | Identifier |
| --- | --- |
| App | `com.salsaparapizza.mana.ios` |
| Widget | `com.salsaparapizza.mana.ios.widgets` |

The signed archive uses **Apple Development**, not Apple Distribution.
Both signatures have team `5P4X92K99Q` and `get-task-allow = true`.
Both contain these signed capabilities:

- App Group: `group.com.salsaparapizza.mana.ios`.
- Keychain group: `5P4X92K99Q.com.salsaparapizza.mana.ios.shared`.

The embedded profiles are development profiles for the exact app and widget identifiers.
Their expiration dates are 5 October 2027, at 08:08:59 and 08:09:02 UTC respectively.
Local profile inspection found no App Store profiles for either Mana identifier.
Identity inspection found Apple Development and Developer ID Application, but no valid Apple Distribution identity.
Developer ID Application is for macOS distribution, not iOS App Store signing.

The unsigned archive has no code signature or signed entitlements; `codesign` confirmed it is not signed.
Configured entitlement templates exist, but do not grant unsigned apps those capabilities.

`APP-ARCHIVE-INSPECTION.json` records app-scoped bundle metadata, signatures, profiles, privacy manifests, and linked libraries.
It excludes device identifiers, certificate bodies, and unrelated app profiles.
No export, Organizer/Apple validation, or TestFlight installation was attempted.
The archive commands omitted `-allowProvisioningUpdates`; they did not authorize account changes.

Reproduce the unsigned inspection archive with a new local output path:

```sh
xcodebuild -project ios/ManaIOS.xcodeproj -scheme ManaIOS \
  -configuration Release -destination 'generic/platform=iOS' \
  -derivedDataPath build/app-preparation/unsigned \
  -archivePath build/app-preparation/Mana-UNSIGNED-NOT-FOR-UPLOAD.xcarchive \
  archive CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
```

## Current remaining release steps

Since this snapshot, the owner reports successful daily use and confirms product technical validation is complete. The support and privacy pages are also published. No feature-validation work remains open.

1. Confirm public provider permission and branding rights.
2. Complete provider data-processing review and App Store privacy disclosures.
3. Set up the App Store Connect record, app identifiers, agreements, and an unused version/build number.
4. Obtain an iOS distribution identity and matching App Store profiles.
5. Create and validate the distribution archive. The inspected local archives were development-signed or unsigned.
6. Enter final listing fields, reviewer contact, and authorized review access.
7. Upload through TestFlight after the owner authorizes the upload. Check the distributed build as part of the release pipeline.
8. Submit for App Review after the owner authorizes submission.

These are release operations, permissions, or App Store configuration. They are not outstanding feature-validation tasks.

## Files changed by this workstream

- `ios/Mana/AppInformation.swift` — new destination constants.
- `ios/Mana/ManaSettingsView.swift` — native localized links.
- `ios/Shared/{en,de,es,fr}.lproj/Localizable.strings` — labels and accessibility hints.
- `ios/ManaTests/AppInformationTests.swift` — destination and bundled-manifest tests.
- `ios/ManaUITests/ManaInformationUITests.swift` — localized/accessibility UI tests.
- `scripts/generate-ios-project.py` — reproducible app/widget manifest generation.
- `ios/Mana/PrivacyInfo.xcprivacy` — generated app manifest.
- `ios/ManaWidgets/PrivacyInfo.xcprivacy` — generated widget manifest.
- `app-store-release-prep/verification/APP-PREPARATION.md` — this report.
- `app-store-release-prep/verification/APP-ARCHIVE-INSPECTION.json` — inspected bundle evidence.

Regeneration did not change the committed project, schemes, plist values, or entitlement templates.
Changes in website, screenshots, metadata, MANUAL, and parent checklists belong to other workstreams.
