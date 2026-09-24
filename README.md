# Mana

Mana is a local macOS menu-bar app for Codex and OpenCode Go usage. Add a ChatGPT account through OpenAI sign-in and paste an OpenCode Go API key in Settings; Mana works independently of locally installed provider CLIs.

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

Mana runs in the menu bar when launched as an app. Select the `dial.medium` icon to open the usage popover. Use Settings to configure credentials, test providers, or change the refresh interval. The default interval is 60 seconds.

## Command line

Build the app, then link its executable into a directory on your `PATH`:

```sh
ln -s "$HOME/Library/Developer/Xcode/DerivedData/Mana-"*/Build/Products/Debug/Mana.app/Contents/MacOS/Mana "$HOME/.local/bin/mana"
mana --help
```

The lowercase `mana` command fetches current usage once without opening the menu-bar app. Examples:

```sh
mana                            # both providers, human-readable
mana --provider codex           # ChatGPT-plan Codex usage
mana --provider opencode-go     # OpenCode Go usage
mana --provider all --json      # machine-readable array
mana --version
# For a one-off key without saving it:
your-key-command | mana --provider opencode-go --key-stdin --json
```

`--json` returns a JSON array with provider names, windows, used percentages, and reset times. A provider failure produces an `error` field; other providers still return data. The command returns status 0 on success, 1 if any provider fails, or 2 for invalid arguments. By default it reads Mana's private credential files. `--key-stdin` accepts an OpenCode Go key from a pipe for one request without saving it. Do not put keys in shell arguments or history. Mana never prints credentials or raw provider responses. You can also run `Mana.app/Contents/MacOS/Mana --cli` directly. A direct app executable with no arguments starts the GUI.

## Credentials

Mana stores OpenAI OAuth tokens and the OpenCode Go API key as plain-text local files under `~/Library/Application Support/Mana/credentials/`. The directory is mode `0700` and each file is mode `0600`; no Keychain access is required. Treat backups of these files as sensitive. Mana does not read or modify provider auth files at runtime. OpenCode Go keys are masked in Settings after saving; the copy button copies the actual key to the clipboard only when clicked.

OpenAI sign-in uses the Codex OAuth flow and a loopback callback on port 1455 (1457 fallback). Codex credentials are an OAuth access token plus ChatGPT account ID. OpenCode Go credentials are a bearer API key.

Usage snapshots remain in memory only. Mana does not save response bodies or usage history.

## Network and status behavior

Mana makes HTTPS requests directly to the provider usage endpoints. Requests use a 15-second timeout and the provider-specific headers used by the existing scripts. Each provider refreshes independently. Mana preserves the last successful snapshot after a failure and marks it stale. It honors `Retry-After` for automatic refreshes and supports manual refresh.

The OpenAI OAuth flow tracks ChatGPT-plan Codex usage; OpenAI API-platform API-key spend is a separate product and is not shown.

## Local build signing

This checkout uses an ad-hoc local signature and disables the App Sandbox. This configuration is intended for local use on this computer, not public distribution. Review the signing and sandbox settings before distributing the app.
