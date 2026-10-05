# Mana

Website: [mana.salsaparapizza.com](https://mana.salsaparapizza.com/)

Mana is a local macOS menu-bar app for Codex, OpenCode Go, and Antigravity usage. Antigravity shows Gemini and Claude/GPT coding-plan quotas, not separate subscriptions. A separate Claude subscription has only a browser link in Settings.

This repository also contains an [iPhone prototype](ios/README.md) for Codex and OpenCode Go. It is not a verified public release; the downloads below are for macOS.

<img width="373" height="430" alt="Mana menu bar" src="https://github.com/user-attachments/assets/ecbbbf4c-b158-44d3-b399-ff73145634e9" />

<img width="565" height="279" alt="Mana settings" src="https://github.com/user-attachments/assets/443f0218-2d29-4864-8e85-bf2d5bf8d87f" />

## Install and use

Requires macOS 13 or later. Install with Homebrew:

```sh
brew install --cask cris7ian/tap/mana
```

Or download the DMG from the [latest release](https://github.com/cris7ian/mana/releases/latest), open it, and drag Mana to Applications. Quit an older copy of Mana before replacing it.

Homebrew also links the `mana` command into its `bin` directory. After installation, run `mana --help` from your terminal.

Open Mana from the menu bar. In Settings, sign in with ChatGPT or add an OpenCode Go API key. For Antigravity, install and sign in to `agy`, then enable it and set its executable path. Mana shows Gemini and Claude/GPT five-hour and weekly quotas without reset times. Settings also links to your separate Claude subscription.

On macOS, Mana saves credentials as private, plain-text files in `~/Library/Application Support/Mana/credentials/`. Keep backups of that folder private. macOS usage data is not saved.

## CLI

The installed app includes the `mana` command. To run it without setup:

```sh
/Applications/Mana.app/Contents/MacOS/Mana --help
```

For a DMG install, link the executable into a directory on your `PATH`:

```sh
mkdir -p "$HOME/.local/bin"
ln -s /Applications/Mana.app/Contents/MacOS/Mana "$HOME/.local/bin/mana"
```

Add `~/.local/bin` to your `PATH` if necessary. Then run `mana --help` for all options, or check usage:

```sh
mana --provider all --json
mana --provider antigravity --json
```

For a one-off OpenCode Go key, pipe it to `mana --provider opencode-go --key-stdin --json`. This does not save the key. Do not pass keys as command arguments. The CLI exits with status 0 on success, 1 if a provider fails, and 2 for invalid arguments.

## Build and test

### Languages

The macOS app, iPhone app, and widgets support English, German, Spanish, and French. English is the development language and fallback.
Mana uses the system’s preferred app language. Set a per-app language in macOS or iPhone Settings to override it.
Provider names and stored quota labels remain unchanged; the interface translates quota labels when it displays them.

Translations live in `Mana/*.lproj`, `ios/Shared/*.lproj`, and the shared package’s `Resources/*.lproj`.
Add each new interface string to all four languages. Preserve format arguments such as `%@` and `%lld`.
Run the coverage check before committing:

```sh
python3 scripts/verify-localizations.py
```

After an iPhone build, also check interpolated strings and App Intents against Xcode’s extracted keys:

```sh
python3 scripts/verify-localizations.py --extracted build/ios/Build/Intermediates.noindex
```

### Build

Requires Xcode 26. Open `Mana.xcodeproj` in Xcode. Select the `Mana` scheme and Run. To run the macOS suite:

```sh
xcodebuild -project Mana.xcodeproj -scheme Mana -configuration Debug \
  -destination 'platform=macOS,arch=arm64' test
```

The menu bar and CLI show remaining percentages. JSON includes `remainingPercent` and `usedPercent`. Codex and OpenCode Go show reset times; Antigravity does not. `--provider all` includes Antigravity only when enabled in Settings; `--provider antigravity` checks it directly. The default refresh interval is 60 seconds.

Both apps use the portable provider package in `Packages/ManaCore/`. Also run the shared-core and iOS suites before committing:

```sh
swift test --package-path Packages/ManaCore
zsh scripts/verify-ios.sh
```

The iOS script requires an installed iPhone simulator with iOS 18 or later. See [iOS verification](ios/README.md#verify) for destination overrides.

## iPhone prototype

The standalone iPhone app targets iOS 18 and later, with Codex device-code approval, OpenCode Go API-key entry, quota cards, and Home Screen/Lock Screen widgets. It does not require a Mac to fetch usage. Antigravity and the CLI remain macOS-only.

Open `ios/ManaIOS.xcodeproj` with the `ManaIOS` scheme, or review labeled synthetic data without provider credentials:

```sh
zsh scripts/review-ios.sh
```

iOS credentials use non-synchronizing, device-only Keychain storage. A protected, backup-excluded App Group cache holds only the latest normalized quotas and freshness metadata, with no history or raw responses. Disconnecting clears that provider's credentials and cached usage. Background and widget refresh times are controlled by iOS, not guaranteed.

Live provider access, public provider permission, and signed-device behavior remain unverified. See the [prototype guide](ios/README.md) and [App Store asset proposal](app-store-release-prep/README.md). TestFlight upload and App Store submission require separate authorization.

## macOS release (maintainers)

Install a Developer ID Application certificate and store notarization credentials with `notarytool` in the Keychain. Copy `.env.release.example` to `.env.release.local` and set your team ID and Keychain profile name there. The local file is ignored by Git. After tests pass, build a signed, notarized DMG with:

```sh
./scripts/release.sh
```

The DMG is written to `build/distribution/`. A plain Xcode Release build uses ad-hoc signing and is not distributable.
