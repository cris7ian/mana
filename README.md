# Mana

Mana is a local macOS menu-bar app for Codex and OpenCode Go usage. It reads provider credentials from the same Pi and OpenCode auth files as `codexusage` and `gousage`, then calls each provider directly. The CLI commands are not required.

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

Mana is a menu-bar-only app. Select the `dial.medium` icon to open the usage popover. Use Settings to test each provider or change the refresh interval. The default interval is 60 seconds.

## Credential sources

Mana reads these files without modifying them:

- Codex: `~/.pi/agent/auth.json` (`openai-codex.access` and `openai-codex.accountId`), then OpenCode auth files (`openai.access` and `openai.accountId`). Mana deliberately does not read `~/.codex/auth.json`.
- OpenCode Go: `~/.local/share/opencode/auth.json` or `~/.config/opencode/auth.json`, using `opencode-go.key` or `opencode.key`.

The app reads only the fields needed for its requests. It does not display or log credential values. It stores usage snapshots in memory only and does not save response bodies or usage history.

## Network and status behavior

Mana makes HTTPS requests directly to the provider usage endpoints. Requests use a 15-second timeout and the provider-specific headers used by the existing scripts. Each provider refreshes independently. Mana preserves the last successful snapshot after a failure and marks it stale. It honors `Retry-After` for automatic refreshes and supports manual refresh.

Codex credentials are an OAuth access token plus ChatGPT account ID. OpenCode Go credentials are a bearer API key. They are distinct credential types.

## Local build signing

This checkout uses an ad-hoc local signature and disables the App Sandbox. The app needs direct read access to the existing provider auth files, and the available signing setup could not build a team-signed sandboxed app. This configuration is intended for local use on this computer, not public distribution. Review the signing and sandbox settings before distributing the app.
