# Mana

Website: [mana.salsaparapizza.com](https://mana.salsaparapizza.com/)

Mana is a local macOS menu-bar app for Codex, OpenCode Go, and Antigravity usage. Antigravity shows Gemini and Claude/GPT coding-plan quotas, not separate subscriptions. A separate Claude subscription has only a browser link in Settings.

<img width="373" height="430" alt="Mana menu bar" src="https://github.com/user-attachments/assets/ecbbbf4c-b158-44d3-b399-ff73145634e9" />

<img width="565" height="279" alt="Mana settings" src="https://github.com/user-attachments/assets/443f0218-2d29-4864-8e85-bf2d5bf8d87f" />

## Install and use

Requires macOS 13 or later. Download the DMG from the [latest release](https://github.com/cris7ian/mana/releases/latest), open it, and drag Mana to Applications. Quit an older copy of Mana before replacing it.

Open Mana from the menu bar. In Settings, sign in with ChatGPT or add an OpenCode Go API key. For Antigravity, install and sign in to `agy`, then enable it and set its executable path. Mana shows Gemini and Claude/GPT five-hour and weekly quotas without reset times. Settings also links to your separate Claude subscription.

Mana saves credentials as private, plain-text files in `~/Library/Application Support/Mana/credentials/`. Keep backups of that folder private. Usage data is not saved.

## CLI

The installed app includes the `mana` command. To run it without setup:

```sh
/Applications/Mana.app/Contents/MacOS/Mana --help
```

To use `mana` from your shell, link it into a directory on your `PATH`:

```sh
mkdir -p "$HOME/.local/bin"
ln -s /Applications/Mana.app/Contents/MacOS/Mana "$HOME/.local/bin/mana"
mana --provider all --json
mana --provider antigravity --json
```

Add `~/.local/bin` to your `PATH` if necessary. Run `mana --help` for all options.

For a one-off OpenCode Go key, pipe it to `mana --provider opencode-go --key-stdin --json`. This does not save the key. Do not pass keys as command arguments. The CLI exits with status 0 on success, 1 if a provider fails, and 2 for invalid arguments.

## Build and test

Open `Mana.xcodeproj` in Xcode. Select the `Mana` scheme and Run. To run the full test suite:

```sh
xcodebuild -project Mana.xcodeproj -scheme Mana -configuration Debug \
  -destination 'platform=macOS,arch=arm64' test
```

The menu bar and CLI show remaining percentages. JSON includes `remainingPercent` and `usedPercent`. Codex and OpenCode Go show reset times; Antigravity does not. `--provider all` includes Antigravity only when enabled in Settings; `--provider antigravity` checks it directly. The default refresh interval is 60 seconds.

## Release (maintainers)

Install a Developer ID Application certificate and store notarization credentials with `notarytool` in the Keychain. Copy `.env.release.example` to `.env.release.local` and set your team ID and Keychain profile name there. The local file is ignored by Git. After tests pass, build a signed, notarized DMG with:

```sh
./scripts/release.sh
```

The DMG is written to `build/distribution/`. A plain Xcode Release build uses ad-hoc signing and is not distributable.
