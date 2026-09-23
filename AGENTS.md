# Mana repository guidance

## Project

Mana is a local macOS menu-bar app written in SwiftUI. It reads provider credentials from existing Pi and OpenCode auth files and calls usage endpoints directly.

## Build and test

Run the full test suite before committing:

```sh
xcodebuild -project Mana.xcodeproj -scheme Mana -configuration Debug \
  -destination 'platform=macOS,arch=arm64' test
```

Use the shared `Mana` scheme. Source files are included through Xcode synchronized groups.

## Safety and privacy

- Never print, log, fixture, or commit credential values.
- Read only the provider fields Mana needs. Never write to provider auth files.
- Do not read `~/.codex/auth.json`.
- Keep response bodies and usage snapshots out of persistent storage.
- Keep error messages sanitized. Do not include HTTP response bodies.

## Implementation

- Preserve independent provider refresh and failure handling.
- Keep provider request and decoding behavior covered by deterministic tests.
- Keep UI copy explicit about provider-specific windows and credential types.
- Avoid adding dependencies or storage layers unless the requirement needs them.
