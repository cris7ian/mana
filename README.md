# Mana

Mana is a local macOS menu-bar app for Codex and OpenCode Go usage. Add a ChatGPT account through OpenAI sign-in and paste an OpenCode Go API key in Settings; Mana works independently of locally installed provider CLIs and that's why I build it. I use Codex locally with my work subscription but my personal stuff is wired through my personal OpenAI account and every other provider wants to read directly from Codex auth.

<img width="373" height="430" alt="image" src="https://github.com/user-attachments/assets/ecbbbf4c-b158-44d3-b399-ff73145634e9" />

<img width="565" height="279" alt="image" src="https://github.com/user-attachments/assets/443f0218-2d29-4864-8e85-bf2d5bf8d87f" />

## Install

Download the DMG from the [latest GitHub release](https://github.com/cris7ian/mana/releases/latest). Open it and drag Mana to Applications. The download is signed with Developer ID and notarized by Apple. macOS 13 or later is required.

## Build and launch

```sh
xcodebuild -project Mana.xcodeproj -scheme Mana -configuration Debug \
  -destination 'platform=macOS,arch=arm64' build
open "$HOME/Library/Developer/Xcode/DerivedData/Mana-"*/Build/Products/Debug/Mana.app
```

Run tests with:

```sh
xcodebuild -project Mana.xcodeproj -scheme Mana -configuration Debug \
  -destination 'platform=macOS,arch=arm64' test
```

Mana runs in the menu bar when launched as an app. Select the icon to open the usage popover. Use Settings to configure credentials, test providers, or change the refresh interval. The default interval is 60 seconds.

## Command line

Build the app, then link its executable into a directory on your `PATH`:

```sh
ln -s "$HOME/Library/Developer/Xcode/DerivedData/Mana-"*/Build/Products/Debug/Mana.app/Contents/MacOS/Mana "$HOME/.local/bin/mana"
mana --help
```

The lowercase `mana` command fetches current usage once without opening the menu-bar app. Human-readable output uses framed, provider-specific usage tables with progress bars, local reset times, and status details. Progress-bar colors appear only in interactive terminals; `NO_COLOR` disables them. Provider failures are shown without hiding results from other providers. Examples:

```sh
mana                            # both providers, human-readable
mana --provider codex           # ChatGPT-plan Codex usage
mana --provider opencode-go     # OpenCode Go usage
mana --provider all --json      # machine-readable array
mana --version
# For a one-off key without saving it:
your-key-command | mana --provider opencode-go --key-stdin --json
```

`--json` returns an array of provider records with usage windows, status, and available reset/receipt times; a provider failure produces an `error` field, while other providers still return data. The command returns status 0 on success, 1 if any provider fails, or 2 for invalid arguments. By default it reads Mana's private credential files. `--key-stdin` accepts an OpenCode Go key from a pipe for one request without saving it. Do not put keys in shell arguments or history. Mana never prints credentials or raw provider responses. You can also run `Mana.app/Contents/MacOS/Mana --cli` directly. A direct app executable with no arguments starts the GUI.

## Credentials

Mana stores OpenAI OAuth tokens and the OpenCode Go API key as plain-text local files under `~/Library/Application Support/Mana/credentials/`. The directory is mode `0700` and each file is mode `0600`; no Keychain access is required. Treat backups of these files as sensitive. Mana does not read or modify provider auth files at runtime. OpenCode Go keys are masked in Settings after saving; the copy button copies the actual key to the clipboard only when clicked.

OpenAI sign-in uses the Codex OAuth flow and a loopback callback on port 1455 (1457 fallback). Codex credentials are an OAuth access token plus ChatGPT account ID. OpenCode Go credentials are a bearer API key.

Usage snapshots remain in memory only. Mana does not save response bodies or usage history.

## Network and status behavior

Mana makes HTTPS requests directly to the provider usage endpoints. Requests use a 15-second timeout and the provider-specific headers used by the existing scripts. Each provider refreshes independently. Mana preserves the last successful snapshot after a failure and marks it stale. It honors `Retry-After` for automatic refreshes and supports manual refresh.

The OpenAI OAuth flow tracks ChatGPT-plan Codex usage; OpenAI API-platform API-key spend is a separate product and is not shown.

## Distribution outside the Mac App Store

Release builds enable Hardened Runtime. Local builds and CI still use ad-hoc signing; they are not distributable. Mana is not sandboxed because it uses a loopback OAuth listener and private files under Application Support. The release script creates a universal macOS app in a notarized DMG with a drag-to-Applications link. Do not distribute an ad-hoc build or an app extracted from the DMG separately.

Prerequisites on the release Mac:

1. Join the Apple Developer Program and confirm the team ID and intended bundle ID (`com.salsaparapizza.mana`).
2. In Xcode → Settings → Accounts → your team → Manage Certificates, create or import a **Developer ID Application** certificate. Keep its private key in the login Keychain. `Apple Development` is not a substitute.
3. Generate an [app-specific password](https://support.apple.com/en-us/102654) for the Apple ID used for notarization. Store notarization credentials in the Keychain. The command prompts for the password; do not put it in a command argument or this repository:

   ```sh
   xcrun notarytool store-credentials mana-notary \
     --apple-id 'your-apple-id@example.com' --team-id YOUR_TEAM_ID
   ```

4. Run the full test suite, then build and notarize the DMG:

   ```sh
   xcodebuild -project Mana.xcodeproj -scheme Mana -configuration Debug \
     -destination 'platform=macOS,arch=arm64' test
   APPLE_TEAM_ID=YOUR_TEAM_ID NOTARY_PROFILE=mana-notary ./scripts/release.sh
   ```

The script checks for the correct Developer ID identity, archives the Release build, verifies the app's signature and Hardened Runtime, signs the DMG, submits it to Apple's notary service, staples the ticket, and verifies Gatekeeper acceptance. The result is `build/distribution/Mana-<version>.dmg`. Open the DMG and drag Mana to Applications. To make another release of the same version, move the existing DMG first. Never commit signing keys, app-specific passwords, or provider credentials.
