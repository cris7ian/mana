# Website preparation verification

## Result

This is a historical source-preparation report. The support and privacy pages have since been published to GitHub Pages and verified over HTTPS:

- `https://mana.salsaparapizza.com/support.html`
- `https://mana.salsaparapizza.com/privacy.html`

The homepage iPhone section and app link remain deferred by the owner. See `../MANUAL.md` for current App Store release status.

## Changes

- `docs/index.html`: added a benefit-led iPhone pre-release section, two existing real-app Demo captures, support navigation, and privacy footer link. Preserved Mac download links, Homebrew copy button, CLI section, Mac screenshot, and creator copy.
- `docs/support.html`: actual creator contact, provider connection guidance, refresh/widget limitations, safe issue-reporting instructions, and disconnect guidance.
- `docs/privacy.html`: source-grounded iPhone authentication, provider requests, credential storage, widget cache, retention, and deletion details. Separately describes Mac plain-text credential files and website/support services.
- `docs/launch.css`: existing dark palette, responsive screenshot gallery and information-page layouts. Fixed narrow-screen grid overflow and navigation overlap found during verification.
- `docs/llms.txt`: support/privacy source targets, accurate network flows, separate Mac storage model, and retained public-release gates.
- `docs/sitemap.xml`: added support and privacy targets.
- `docs/assets/iphone-usage-demo.png` and `docs/assets/iphone-codex-demo.png`: exact copies of existing source captures, not newly invented screenshots.

The iPhone section explicitly says pre-release, iOS 18+, Codex/OpenCode Go, no App Store availability, and system-controlled widget refresh. No App Store URL was invented. Widget screenshots were not assumed or fabricated.

## Contact evidence

Read-only GitHub discovery:

```sh
gh api repos/cris7ian/mana --jq '{html_url,has_issues,private}'
```

Returned:

```json
{"has_issues":true,"html_url":"https://github.com/cris7ian/mana","private":false}
```

A read-only GET of `repos/cris7ian/mana/issues` succeeded and returned an empty list. The repository is public and its issue tracker is enabled. Support uses that real tracker. The page warns that issues are public and require a GitHub account. No email or address was invented.

## Privacy source evidence

Reviewed:

- `ios/Shared/MobileCredentialStore.swift`: non-synchronizing, device-only Keychain items, shared access group, after-first-unlock accessibility.
- `ios/Shared/MobileStore.swift`: protected, backup-excluded latest normalized quota cache; per-provider disconnect clears usage before deleting credentials.
- `ios/Shared/CodexDeviceAuth.swift`: device-code requests, approval polling, token exchange, and refresh requests to `auth.openai.com`.
- `ios/Shared/MobileUsageRuntime.swift`: credential usage, account replacement, token rotation, and direct provider fetches.
- `Packages/ManaCore/Sources/ManaCore/CodexUsageClient.swift`: access token plus ChatGPT account identifier sent to `chatgpt.com/backend-api/wham/usage`.
- `Packages/ManaCore/Sources/ManaCore/OpenCodeGoUsageClient.swift`: API key sent as bearer authentication to `opencode.ai/zen/go/v1/usage`.
- `Packages/ManaCore/Sources/ManaCore/HTTPTransport.swift`: ephemeral transport with no persistent response cache or cookie setting.
- `Mana/Usage/CredentialStore.swift`: Mac credentials in private local plain-text files, directory 0700 and files 0600, not Keychain encryption.
- `ios/README.md`: supported platforms/providers, languages, Demo behavior, refresh/staleness behavior, and outstanding release gates.

Copy does not claim that nothing leaves the device or finalize an App Store “Data Not Collected” label. It describes credentials sent to providers, provider network information, public support submissions, deletion failures, and uninstall retention caveats.

## Screenshot provenance

The copied PNGs match the existing source captures and their provenance hashes:

| Website asset | Existing source | SHA-256 |
| --- | --- | --- |
| `iphone-usage-demo.png` | `app-store-release-prep/screenshots/source/usage-light.png` | `9d6af04388949de3ee457ddbd845205a4699f7cfa1f397bb88df7c7ce596cd65` |
| `iphone-codex-demo.png` | `app-store-release-prep/screenshots/source/codex-light.png` | `150e931098b65395111872e3b50d358eb35ee8016cee468654346ca315e6cf2c` |

Both images display Demo labels. Website captions state that quota values are synthetic, not live-account evidence.

The existing `docs/assets/social-preview.jpg` was visually inspected. Its Mac menu-bar copy remains accurate because the main download/hero is still Mac-focused. The image was retained rather than implying iPhone availability. Support/privacy Open Graph tags use the neutral app icon, not the Mac download card. No script edits were needed.

## Local verification

Server:

```sh
python3 -m http.server 8767 --bind 127.0.0.1 --directory docs
```

Health check returned HTTP 200 and `Content-type: text/html` for `/support.html`.

A temporary standard-library link checker and Playwright browser probe ran with:

```sh
uv run --with playwright python /Users/cristian/.hermes/cache/scratch/mana-website-check.py
```

Result: exit 0.

- Parsed all three HTML pages and checked 54 local resource/link references over HTTP. All returned 200. All local fragment identifiers resolved.
- Tested `/`, `/support.html`, and `/privacy.html` at viewport widths 1280, 390, and 320, each with height 900.
- All nine rendered cases had scroll width equal to viewport width; no horizontal overflow remained.
- Every page image loaded in every viewport case.
- No browser page errors or failed resource requests occurred.
- Homebrew copy control returned `Homebrew install command copied.` at all three widths.
- Computed desktop iPhone columns: `522.922px 549.062px`.
- Computed mobile iPhone columns: `354px` at width 390; `284px` at width 320.
- Body background remained `rgb(11, 17, 28)`.
- Mac hero retained the existing `Puppies Play` font and original download destinations.
- `git diff --check -- docs` passed.

Visual evidence was inspected for desktop iPhone preview, complete mobile iPhone preview, narrow support navigation, and mobile privacy readability.

Temporary evidence files:

- `/Users/cristian/.hermes/cache/scratch/mana-website-preview/results.json`
- `/Users/cristian/.hermes/cache/scratch/mana-website-preview/iphone-1280.png`
- `/Users/cristian/.hermes/cache/scratch/mana-website-preview/iphone-390.png`
- `/Users/cristian/.hermes/cache/scratch/mana-website-preview/iphone-320.png`
- `/Users/cristian/.hermes/cache/scratch/mana-website-preview/support-1280.png`
- `/Users/cristian/.hermes/cache/scratch/mana-website-preview/support-390.png`
- `/Users/cristian/.hermes/cache/scratch/mana-website-preview/support-320.png`
- `/Users/cristian/.hermes/cache/scratch/mana-website-preview/privacy-1280.png`
- `/Users/cristian/.hermes/cache/scratch/mana-website-preview/privacy-390.png`
- `/Users/cristian/.hermes/cache/scratch/mana-website-preview/privacy-320.png`

Scratch evidence can be pruned by the runtime. This report preserves the observed results.

## Issues and boundaries

The built-in browser screenshot tool timed out. A local Playwright browser provided successful screenshots and computed DOM evidence instead. Animated hero elements also blocked stability-based scrolling; the probe used instant DOM scrolling and section screenshots.

The 320px probe exposed existing hero grid minimum-width overflow and crowded new navigation. Both were corrected in scoped launch CSS and re-tested.

At the time of this report, support/privacy delivery and live use were unverified. The pages have since been published, and the owner reports successful daily use with technical validation complete. Public provider permission, final App Store privacy classification, and distribution remain release steps. The iPhone app is not a public App Store release.
