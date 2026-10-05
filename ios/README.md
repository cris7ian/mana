# Mana iPhone prototype

Requires Xcode 26 and an iOS 18 or later simulator/device. The app supports iPhone.

The app and widgets use the shared provider package in `Packages/ManaCore/`. See the [App Store asset proposal](../app-store-release-prep/README.md) for release preparation. The existing DMG and Homebrew installation are macOS-only.

The app and widgets support English, German, Spanish, and French, with English fallback. Set a per-app language in iPhone Settings. Translation tables live in `ios/Shared/*.lproj` and `Packages/ManaCore/Sources/ManaCore/Resources/*.lproj`.

## Review without provider credentials

1. Open `ios/ManaIOS.xcodeproj` in Xcode.
2. Select the `ManaIOS` scheme and an iPhone simulator.
3. Run the app.
4. Open Settings.
5. Enable Demo.
6. Open Usage.

For automated review, launch with `--demo`. All sample quota values are synthetic.
Demo is off by default and remembers your choice. Its toggle is the last settings option, above the creator footer.
Demo does not read credentials, persist quota snapshots, or contact providers.
The demo preference is shared with widgets, which label their sample data.

Build and launch the labeled demo from the terminal:

```sh
zsh scripts/review-ios.sh
```

Add **Mana overview** to the Home Screen for both providers.
Add **Codex quotas** or **OpenCode Go quotas** for a provider or Lock Screen quota window.
Both provider widgets let you change the provider and Lock Screen quota in Edit Widget.
Gallery previews use synthetic quotas without a Demo label. Installed widgets label samples only when Demo is enabled.
Widget updates are system-controlled, not continuous polling.
The dashboard shows reset countdowns beside quota headings. Tap a countdown to see the full reset date.

## Connect a real provider

Disable Demo before connecting. Codex uses browser device-code approval.
Return to Mana after approving the code. Interrupted approval requests retry with the same code until it expires.
Explicit Cancel stops sign-in. Pending approval stays in memory; force-quitting Mana requires a new code.
OpenCode Go accepts an API key in a secure field.
Never extract tokens from another app or CLI.

Live account access is not verified by synthetic tests or simulator screenshots.
Public third-party provider permission, signed-device storage/widget behavior, privacy disclosures, and published support/privacy URLs remain release gates.
Do not distribute this prototype as a verified public release.

## Device signing

The project uses the existing developer team as a signing reference.
Enable automatic signing for the app and widget extension.
Register their App Group and shared Keychain group in the developer account.
The app identifiers are `com.salsaparapizza.mana.ios` and its `.widgets` extension.
The shared container is `group.com.salsaparapizza.mana.ios`.

Credentials use non-synchronizing, device-only Keychain storage after first unlock.
Simulator scripts use local ad-hoc signing so Keychain operations can run without a distribution certificate.
Unsigned simulator apps cannot use Keychain. App/extension Keychain sharing must be verified on a signed physical device.
The protected, backup-excluded cache holds only the latest normalized quota values and freshness metadata.
Disconnecting a provider removes its credentials and clears its cached usage.
App and widget fetches share per-provider file locks, including token refresh and account changes.
An actor alone cannot coordinate those separate processes.

The app refreshes on foreground entry, pull-to-refresh, and every 60 seconds while active.
The timer stops when inactive. Manual and automatic refreshes honor provider backoff.
Usage becomes stale after 15 minutes or a failed fetch; failures retain the last valid snapshot.

## Verify

```sh
python3 scripts/verify-localizations.py
swift test --package-path Packages/ManaCore
zsh scripts/verify-ios.sh
```

Choose another installed simulator with `MANA_IOS_DESTINATION`:

```sh
MANA_IOS_DESTINATION='platform=iOS Simulator,name=iPhone 16,OS=18.3' zsh scripts/verify-ios.sh
```

Keep the full macOS suite passing as documented in `AGENTS.md`.
UI tests use a Debug-only `--ui-testing` runtime with no accounts, credentials, cache, or provider requests.
Turning Demo off in those tests cannot access accounts retained by a reused simulator.
The standard-library-only generator reproduces the project, schemes, plists, entitlements, and brand assets:

```sh
python3 scripts/generate-ios-project.py
```

Change the generator before editing generated configuration. Regeneration overwrites those files, but does not modify Swift sources or the Mac project.

App Store screenshot capture uses a dedicated, credential-isolated simulator with an iOS 26 or later runtime. See [asset reproduction](../app-store-release-prep/README.md#reproduce) for commands and dependencies.

The prototype does not include notifications, Antigravity, multiple accounts, native iPad support, a server, cloud sync, or usage history.
