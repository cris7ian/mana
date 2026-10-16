# Mana agent guidance

## Verify

Use change-scoped checks before committing. Stage only the intended changes, then run:

```sh
python3 scripts/verify.py --staged
```

The index selects paths; checks use working-tree contents. Do not select unrelated dirty files merely because they exist.
Use explicit repository-relative paths during development, for example `python3 scripts/verify.py docs/index.html`.
Use `--dry-run` to inspect the plan without running checks.

- Website changes run static link, asset, fragment, and JavaScript syntax checks. Also inspect rendered desktop/mobile layouts when presentation changes. Do not launch Xcode for website-only work.
- macOS changes run localization and macOS tests.
- Shared-core changes also run core tests and iOS unit tests.
- iOS runtime changes run localization and iOS unit tests. App/view/widget/project and translation changes also run behavioral UI tests. Add `--ui` for other user-visible iOS changes.
- Screenshot capture is not part of the routine local UI loop. Run the capture workflow when changing App Store assets.
- Verification tooling has simulator-free regression tests in `scripts/tests/`.
- Unknown build/configuration changes select full verification. Documentation-only changes need review, not native test runs.

Run `python3 scripts/verify.py --full` for release validation or cross-platform changes that need all suites.
CI retains the complete native suites, including UI tests, on macOS 15 with Xcode 26.0.1.
Do not rerun completed suites after an interruption; resume only unfinished tests when inputs are unchanged.

`zsh scripts/verify-ios.sh --unit` runs iOS unit tests. `--ui` runs behavioral UI tests without App Store screenshot capture.
Without an argument, the iOS script runs the full suite and selects an installed iPhone simulator. Override it with `MANA_IOS_DESTINATION`; an iOS 18 or later runtime is required. It tests the app and builds the embedded widget extension with local ad-hoc signing. Simulator tests do not verify app/widget Keychain sharing on a signed device.

Both Xcode projects use synchronized groups; new Swift files in those groups do not need project-file entries.

## Shared core and iPhone

Portable quota models, clients, decoders, transport, errors, and quota localization live in `Packages/ManaCore/`. Keep AppKit, desktop OAuth/storage, CLI, and `agy` execution in the macOS adapters. iPhone device-code authentication and app/widget runtime code remain under `ios/`.

`scripts/generate-ios-project.py` generates the iOS project, schemes, plists, entitlements, and brand assets. Change the generator before changing generated configuration; regeneration overwrites those files. It does not modify Swift sources or the Mac project.

The app and widgets share per-provider `MobileStore.withLock` file locks across credential changes and fetches. Preserve cross-process coordination; an actor alone cannot serialize app/extension access. Keep the labeled Demo runtime credential-free. UI tests use the Debug-only `--ui-testing` runtime, even when they disable Demo.

English is the development language and fallback; maintain German, Spanish, and French alongside it. Localize displayed quota labels without changing provider names or stored labels. Keep format arguments and plural rules consistent across the app, iOS shared, and ManaCore resource tables. `scripts/verify-localizations.py` checks coverage and formats; it does not replace rendered UI tests.

## Website and providers

The static website lives in `docs/index.html`; keep `docs/llms.txt` and the generated `docs/assets/social-preview.jpg` in sync with public copy. Generate the card with `python3 scripts/social-card.py --variant icon --out docs/assets/social-preview.jpg`.

Antigravity usage comes from the signed-in `agy` CLI, not a separate Gemini or Claude subscription. Its Gemini and Claude/GPT quota bars omit reset dates because `agy` reports shifting timestamps. Keep the Claude subscription browser link distinct.

## Release

A plain Release build is ad-hoc signed. Never publish it. The release script needs a Developer ID Application certificate and a local `notarytool` Keychain profile. Put the team ID and profile name in ignored `.env.release.local` (see `.env.release.example`), or set `APPLE_TEAM_ID` and `NOTARY_PROFILE` in the environment. The script signs, notarizes, staples, and verifies the DMG. Keep signing credentials out of git.

Use the `mana-release` skill for versioned installer and public-release work. Keep the workflow there; keep release-signing and credential safety constraints here.

The iPhone app is a pre-release app, not a public App Store release. The owner reports successful daily use and confirms product technical validation is complete; synthetic asset captures remain demo evidence only. Public provider permission, final App Store privacy answers, App Store Connect setup, distribution signing/archive, TestFlight, and App Review remain release steps. Support and privacy pages are published on the existing site. See `ios/README.md` and `app-store-release-prep/MANUAL.md`. TestFlight upload and App Store submission require explicit authorization.

## Safety

- Never read `~/.codex/auth.json` or modify provider auth files.
- Never print, log, fixture, or commit credential values.
- Keep macOS usage snapshots and all provider response bodies out of persistent storage and error messages.
- iOS may persist only each provider's latest normalized quota values, fetch time, and safe freshness metadata in its protected App Group cache. Keep no history or raw responses. Exclude the cache from backup and clear it on disconnect or account replacement. Store iOS credentials only in non-synchronizing, device-only Keychain items.
- Preserve independent provider refresh and failure handling; test request and decoding changes deterministically.
