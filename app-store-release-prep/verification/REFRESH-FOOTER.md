# Refresh footer and asset rebuild

Verified locally on 2026-10-07. This is not a submitted release.

## UI change

- Moved `Refreshing…` from a separate status row into the provider card footer.
- `Updated hh:mm` remains leading; refreshing remains trailing on the same line when space permits.
- Preserve the refreshing label's layout footprint while idle; hide it from accessibility while idle.
- Use a stable stacked footer at large text sizes when a single line does not fit.
- Preserve an empty first-fetch footer for configured providers without saved usage.
- Keep sample-data disclosure unchanged. Demo screenshots omit live update timestamps.

## Verification

- Full iOS test suite: 78 passed, 0 failed, 0 skipped.
- Result: `build/refresh-footer-verification-20261007-004854.xcresult`.
- Focused layout tests passed again after attaching the native render to a simulator window scene.
- Result: `build/footer-layout-scene.xcresult`.
- Layout assertions compare loading and idle heights at 320pt and 440pt widths.
- Both default and accessibility3 Dynamic Type sizes are covered, with and without saved usage.
- Native rendering was visually reviewed: timestamp leading, refreshing trailing, no clipping.
- Native render: `build/footer-layout-scene-attachments/79C08CD8-27E6-4067-8FB1-69DB5899B402.png`.
- Localization validation passed across English, German, Spanish, and French.
- Script syntax and help checks passed.

## Fresh App Store assets

Executed `zsh scripts/capture-app-store.sh` against the updated app.

- Capture evidence: `build/app-store-capture-20261007-004751-40366.xcresult`.
- Eight original app/widget captures imported without modification.
- Fifteen opaque PNG exports rendered across three sizes.
- Contact sheet visually reviewed; website-inspired backgrounds and sample disclosures remain intact.
- Dimensions, formats, source/export hashes, metadata limits, ZIP CRCs, membership, and exact bytes verified.
- The widget capture is a genuine installed Home Screen widget; no Lock Screen screenshot is claimed.

## Rebuild

From the repository root:

```sh
zsh scripts/capture-app-store.sh
```

The command builds, captures, imports, renders, verifies, and creates the ZIP.
Use `--reuse-captures` only for marketing copy/background changes, never app UI changes.
See `app-store-release-prep/README.md` for prerequisites and output paths.

No commit, push, publication, build upload, or submission was performed.
