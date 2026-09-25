# Mana agent guidance

## Verify

Run the full suite before committing. CI uses this command on macOS 15 with Xcode 26.0.1:

```sh
xcodebuild -project Mana.xcodeproj -scheme Mana -configuration Debug \
  -destination 'platform=macOS,arch=arm64' test
```

Source files use Xcode synchronized groups; new Swift files do not need project-file entries.

## Release

A plain Release build is ad-hoc signed. Never publish it. Use `scripts/release.sh` with `APPLE_TEAM_ID` and `NOTARY_PROFILE` to sign, notarize, staple, and verify the DMG. It requires a Developer ID Application certificate and a local `notarytool` Keychain profile. Keep signing credentials out of git.

Use the `mana-release` skill for versioned installer and public-release work. Keep the workflow there; keep release-signing and credential safety constraints here.

## Safety

- Never read `~/.codex/auth.json` or modify provider auth files.
- Never print, log, fixture, or commit credential values.
- Keep usage snapshots and provider response bodies out of persistent storage and error messages.
- Preserve independent provider refresh and failure handling; test request and decoding changes deterministically.
