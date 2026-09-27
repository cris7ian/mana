# Mana

Website: [mana.salsaparapizza.com](https://mana.salsaparapizza.com/)

Mana is a local macOS menu-bar app for Codex, OpenCode Go, and Antigravity coding-plan usage. Add a ChatGPT account through OpenAI sign-in, paste an OpenCode Go API key, or connect your installed `agy` CLI in Settings. Antigravity uses its own signed-in CLI; Mana never reads its credentials. Claude subscription usage is currently a manual link because Claude Code does not expose its plan bars through print mode. I use Codex locally with my work subscription, while personal usage connects through my personal OpenAI account. Other providers often read directly from Codex auth.

<img width="373" height="430" alt="Mana menu bar" src="https://github.com/user-attachments/assets/ecbbbf4c-b158-44d3-b399-ff73145634e9" />

<img width="565" height="279" alt="Mana settings" src="https://github.com/user-attachments/assets/443f0218-2d29-4864-8e85-bf2d5bf8d87f" />

## Install and use

Requires macOS 13 or later. Download the DMG from the [latest release](https://github.com/cris7ian/mana/releases/latest), open it, and drag Mana to Applications. Quit an older copy of Mana before replacing it.

Open Mana and select its menu-bar icon. In Settings, sign in with your ChatGPT account, add an OpenCode Go API key, and enable Antigravity with the path to your installed `agy` CLI. Antigravity reads your Google AI coding-plan quota from `agy --print '/usage' --output-format json`; its Claude/GPT bucket is **Antigravity quota**, not your separate Claude subscription. Mana hides Antigravity reset timestamps because they currently shift on every poll. Use the Claude settings link to check that subscription manually.

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

Mana runs in the menu bar when launched as an app. Select the icon to see how much Codex, OpenCode Go, and enabled Antigravity usage remains. The app and human-readable CLI show the percentage left in each window. CLI JSON includes both `remainingPercent` and the compatible `usedPercent` field. Codex and OpenCode Go reset times count down in days and hours, or hours and minutes when less than a day remains. Antigravity resets remain hidden pending verification. Use Settings to configure credentials, test providers, or change the refresh interval. The default interval is 60 seconds.

## Release (maintainers)

Install a Developer ID Application certificate and store notarization credentials with `notarytool` in the Keychain. After tests pass, build a signed, notarized DMG with:

```sh
APPLE_TEAM_ID=YOUR_TEAM_ID NOTARY_PROFILE=YOUR_PROFILE ./scripts/release.sh
```

The DMG is written to `build/distribution/`. A plain Xcode Release build uses ad-hoc signing and is not distributable.
