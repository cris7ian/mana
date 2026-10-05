# Preparation verification — 2026-10-05

## Passed during asset preparation

| Check | Result |
| --- | --- |
| Dedicated simulator capture tests | 2 passed; seven original demo screenshots exported |
| Full iOS suite | 54 passed, 0 failed, 0 skipped |
| Full macOS suite | 32 passed, 0 failed, 0 skipped |
| Shared ManaCore suite | 11 test definitions passed, including parameterized cases |
| Asset verifier | Eight RGB PNG exports, dimensions, metadata limits, field consistency, hashes, icon, and supporting art passed |
| Shell syntax | `zsh -n scripts/capture-app-store.sh` passed |
| Whitespace | `git diff --check` passed |

The simulator uses iPhone 17 Pro Max with iOS 26.5. No live provider credentials were used.

The original captures and every composed slide were visually inspected. Slides 2 and 3 use complete native provider-card crops to make quotas readable. Their crop coordinates are included in the export manifest.

## Website cleanup

The separate staged website and HTML review page were removed at the user's request. The renderer no longer creates web assets. The existing website in `docs/` remains untouched by this cleanup.

The approved artwork is preserved in `app-store-release-prep/`. Support and privacy-policy URLs must be confirmed against the existing website before submission.

## Evidence

Local result bundles are in ignored `build/`:

- `app-store-capture-20261005-153259.xcresult`
- `app-store-full-ios-check.xcresult`
- `app-store-full-macos-check.xcresult`

Xcode emitted build-number/debugger diagnostics and macOS XCTest deployment warnings. All final test runs completed with a Passed result.

The first capture attempt used the wrong test-target name. The script now selects `ManaIOSUITests/ManaAppStoreScreenshotTests`. The attachment importer also handles Xcode's generated filename suffixes.

## Later documentation audit — 2026-10-05

The preparation results above are historical, not a passing result for every later working-tree change.

| Recheck | Result |
| --- | --- |
| Localization coverage and formats | Passed; 235 keys across English, German, Spanish, and French |
| macOS suite | 33 tests passed, including localization packaging |
| Shared ManaCore suite | 16 test definitions passed, including parameterized cases |
| Asset verifier | Passed; metadata, dimensions, generated fields, and source/export hashes still match |
| iOS verification script | The 17:57 run failed with exit 65; UI tests lost app connections and test runners restarted repeatedly |

The iOS failure cause is not established. The final rerun below passed on a different simulator runtime; it does not establish the cause.

## Final localization and test cleanup verification — 2026-10-05

| Check | Result |
| --- | --- |
| Localization coverage and formats | Passed; 221 keys across English, German, Spanish, and French, including the iOS compiler-extraction audit |
| macOS suite | 22 tests passed, including localization packaging and desktop-specific safety checks |
| Shared ManaCore suite | 23 test definitions passed, including parameterized decoding, HTTP failures, credential validation, localization, and plural cases |
| Full iOS suite | 67 tests passed: 56 unit tests and 11 UI tests, including German, Spanish, French, and English fallback |
| Generated iOS project/configuration/assets | 19 generated files match their repository versions |
| Asset verifier | Passed; metadata, dimensions, generated fields, and source/export hashes still match |
| Shell syntax and whitespace | Passed |

The final iOS run used iPhone SE (3rd generation) with iOS 18.3.1 and local ad-hoc signing.
The widget extension built and packaged all four language resources. These checks do not verify signed-device Keychain sharing.

Shared decoder fixtures and provider tests now live in ManaCore instead of repeating in the Mac suite.
The cleanup removed assignment-only checks and unused Mac translations now owned by ManaCore.
Lock tests use explicit coordination rather than a delay. App/widget tests retain credential isolation, cancellation, provider independence, and demo safety checks.

Final local logs are in ignored `build/final-mac-tests.log`, `build/final-core-tests.log`, and `build/final-ios-tests.log`.

## Not established by these checks

- Public provider authorization or successful live account access.
- Real-device Keychain and App Group behavior.
- TestFlight or distribution signing.
- Real-device widget and background refresh behavior.
- Published HTTPS pages or completed privacy disclosures.
- App Store Connect configuration, upload, submission, or approval.

This report describes asset preparation. It does not authorize or certify a public release.
