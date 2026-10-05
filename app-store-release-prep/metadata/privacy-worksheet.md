# App privacy worksheet — not final disclosure answers

Standing Desk is an offline Bluetooth utility. Mana contacts provider services. **Do not inherit Standing Desk's “Data Not Collected” answer automatically.**

## Observed design

| Item | Source | Behavior |
| --- | --- | --- |
| Provider credentials | `ios/Shared/MobileCredentialStore.swift` | Non-synchronizing, device-only Keychain items |
| Latest usage | `ios/Shared/MobileStore.swift` | Protected App Group cache, excluded from backup; normalized values and freshness metadata only |
| Demo preference | `ios/Mana/MobileAppModel.swift` | App Group `UserDefaults`, shared with widgets |
| Disconnect | `ios/Shared/MobileStore.swift` | Clears cached usage and removes the selected provider's credentials |
| Authentication | `ios/Shared/CodexDeviceAuth.swift` | HTTPS requests to OpenAI authentication services |
| Codex usage | `Packages/ManaCore/Sources/ManaCore/CodexUsageClient.swift` | Authenticated HTTPS request to provider usage service |
| OpenCode Go usage | `Packages/ManaCore/Sources/ManaCore/OpenCodeGoUsageClient.swift` | Authenticated HTTPS request to OpenCode Go usage service |
| Analytics, advertising, developer-operated backend | Inspected app and shared Swift source | None identified in the preparation audit; recheck the final archive and dependencies |

## Required decisions

1. Inspect the distribution archive and its complete dependency list.
2. Confirm there are no added telemetry or crash-reporting services.
3. Map every off-device data flow, including credentials and provider account identifiers.
4. Determine which provider processing counts as collection under Apple's current definitions.
5. Confirm retention and collection practices with each provider; do not infer them from Mana's local storage.
6. Select data types, purposes, linkage, and tracking answers from that analysis.
7. Select “Data Not Collected” only if the complete analysis supports it.
8. Verify the final policy on the existing website against the released implementation and confirm its HTTPS URL.

## Privacy manifests

No `PrivacyInfo.xcprivacy` was found in the inspected iOS source when this package was prepared.

The app and widget use App Group `UserDefaults`. Audit required-reason APIs in both targets and shared dependencies. Add the applicable approved reasons to each final bundle. Do not invent reasons or mark a manifest integrated without verifying the archive.

A privacy manifest and App Store privacy answers are separate requirements. Neither replaces the public privacy policy.

References:

- https://developer.apple.com/app-store/app-privacy-details/
- https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
- https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api

No legal conclusion or completed App Store Connect questionnaire is claimed here.
