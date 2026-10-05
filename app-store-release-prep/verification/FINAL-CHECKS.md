# Verification

## Asset checks

Run from the repository root:

```sh
python3 scripts/app-store-assets.py verify
zsh -n scripts/capture-app-store.sh
git diff --check
```

The asset verifier checks:

- All eight screenshot exports exist and match their manifest hashes.
- The exports are RGB PNGs with no alpha channel.
- The large set is 1320 × 2868; the legacy set is 1284 × 2778.
- Metadata is within name, subtitle, promotional-text, description, and keyword limits.
- Copy-ready text fields match the JSON source.
- Raw screenshot hashes match their capture provenance.
- The icon is opaque RGB at 1024 × 1024.
- Contact-sheet and social-card dimensions match their documented sizes.
- The package contains no separate website, HTML pages, or CSS files.

Visually inspect every full-size export. Verify readable copy, safe margins, unmodified app screens, and visible demo labels.

Apple's specifications checked during preparation:

https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/

## Re-capture

```sh
zsh scripts/capture-app-store.sh
```

The script creates or reuses a dedicated `Mana App Store Assets` iPhone 17 Pro Max simulator. It runs only `ManaAppStoreScreenshotTests` in the credential-isolated Debug test runtime.

The resulting `.xcresult` and intermediate attachment manifest stay in ignored `build/`. The source PNGs contain only synthetic demo data. Keep provider responses and credentials out of the package.

The script does not modify app authentication, connect a provider, or remove existing simulators.

## App release checks

Asset verification does not replace app verification. Before committing or preparing the final archive, run:

```sh
python3 scripts/verify-localizations.py
swift test --package-path Packages/ManaCore
zsh scripts/verify-ios.sh
xcodebuild -project Mana.xcodeproj -scheme Mana -configuration Debug \
  -destination 'platform=macOS,arch=arm64' test
```

Inspect the signed archive for app and widget identifiers, matching versions, signing, App Group and Keychain entitlements, and required privacy manifests. Test the distribution build on a real device through TestFlight.

**Open release gates:** provider permission, live account access, distribution signing, real-device Keychain/cache/widget behavior, published public URLs, final privacy answers, and App Review.
