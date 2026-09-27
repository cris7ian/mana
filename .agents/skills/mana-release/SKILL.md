---
name: mana-release
description: Build Mana's signed and notarized macOS installer, or publish a versioned GitHub release. Use whenever asked to prepare an installer, bump Mana's release version, tag a release, or ship/publish Mana.
---

# Mana release

Use the repository's documented release path. Read `AGENTS.md`, `scripts/release.sh`, and the Xcode project version settings before changing files.

## Decide the requested outcome

- For an installer request, build and verify the notarized DMG. Do not push or publish it unless the user asked for a release.
- For an explicit release, complete the GitHub release flow after verification. An explicit request to release, ship, or publish authorizes the push and publication.
- For a versioned installer or release, confirm the intended marketing version. For an installer without a requested version, use the current project version.

## Prepare

1. Inspect the current branch, remotes, tags, GitHub releases, and worktree. Preserve unrelated local changes.
2. Check that the requested tag and `build/distribution/Mana-$VERSION.dmg` do not already exist.
3. If the requested version differs, update `MARKETING_VERSION` and increment `CURRENT_PROJECT_VERSION` in every app and test build configuration.
4. Run the full test command from `AGENTS.md` after source or version changes.
5. For public releases, commit only release-related changes before building. Do not stage unrelated or pre-existing user changes.

## Build and verify the installer

1. Confirm a Developer ID Application identity and a usable local `notarytool` Keychain profile exist. Use the ignored `.env.release.local` file (copy `.env.release.example` if needed). Do not print its contents.
2. Build with the local config. Explicit `APPLE_TEAM_ID` and `NOTARY_PROFILE` environment values override it:

   ```sh
   ./scripts/release.sh
   ```

3. Confirm `build/distribution/Mana-$VERSION.dmg` exists.
4. Verify the app signature, notarization ticket, and Gatekeeper assessment. The release script performs these checks; stop if any check fails.

Do not read, print, or store provider credentials. Keep signing credentials in the Keychain and out of Git. Do not publish an ad-hoc Release build.

## Publish an explicit release

After the DMG passes all checks, create an annotated tag and publish the artifact:

```sh
git tag -a "v$VERSION" -m "Mana $VERSION"
git push origin HEAD "v$VERSION"
gh release create "v$VERSION" "build/distribution/Mana-$VERSION.dmg" \
  --title "Mana $VERSION" --generate-notes
```

Do not force-push. If a tag or release already exists, stop and report it. Do not replace an existing DMG; the release script refuses to overwrite it.

## Update the Homebrew cask after a release

Mana is distributed through the public `cris7ian/homebrew-tap` repository. Its cask is `Casks/mana.rb`; the install command is `brew install --cask cris7ian/tap/mana`.

1. Update the cask only after the matching GitHub Release and DMG are public.
2. Clone the tap to `~/Developer/homebrew-tap` if it is not already there:

   ```sh
   gh repo clone cris7ian/homebrew-tap "$HOME/Developer/homebrew-tap"
   ```

3. Confirm the tap clone has no local changes, then update it with a fast-forward pull:

   ```sh
   git -C "$HOME/Developer/homebrew-tap" status --short --branch
   git -C "$HOME/Developer/homebrew-tap" pull --ff-only
   ```

   Stop and preserve any existing local changes.
4. Calculate the checksum from the exact notarized release DMG:

   ```sh
   shasum -a 256 "build/distribution/Mana-$VERSION.dmg"
   ```

5. In `~/Developer/homebrew-tap/Casks/mana.rb`, set `version` to `$VERSION` and replace `sha256` with the calculated digest. Keep the release URL, macOS requirement, and `app "Mana.app"` artifact intact.
6. Commit and push the tap change. Do not force-push:

   ```sh
   git -C "$HOME/Developer/homebrew-tap" add Casks/mana.rb
   git -C "$HOME/Developer/homebrew-tap" commit -m "Update Mana to $VERSION"
   git -C "$HOME/Developer/homebrew-tap" push
   ```

7. Refresh Homebrew metadata and verify the published cask:

   ```sh
   brew update
   brew audit --cask --strict cris7ian/tap/mana
   brew fetch --cask cris7ian/tap/mana
   ```

Do not publish a checksum until it matches the DMG attached to the public release. If audit or fetch fails, stop and fix the cask before reporting the release complete.

## Replace the running app only when requested

1. Mount the verified DMG read-only. Check the bundled app's version and signature before stopping the installed copy.
2. Quit `/Applications/Mana.app` and wait for its process to exit. Do not replace a running app.
3. Move the old app to a temporary backup, then copy the DMG app to `/Applications/Mana.app` with `ditto`.
4. Verify the installed version, code signature, and Gatekeeper assessment. Launch it and confirm its process is running.
5. If installation or launch fails, restore the backup and report the failure. Trash the backup only after verification succeeds.
6. Detach the DMG and remove the temporary mount directory. Do not touch Mana's credentials or settings.

## Report

Report the commit, tag, release URL, DMG path, and verification result. For a requested local replacement, report the installed version and running status. Include the DMG's SHA-256 when useful. State any remaining gate or local change that was left untouched.
