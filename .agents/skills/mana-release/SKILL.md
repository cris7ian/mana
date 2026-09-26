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

1. Confirm a Developer ID Application identity and a usable local `notarytool` Keychain profile exist.
2. Use their team ID and profile name with the repository script:

   ```sh
   APPLE_TEAM_ID=TEAM_ID NOTARY_PROFILE=PROFILE_NAME ./scripts/release.sh
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

## Replace the running app only when requested

1. Mount the verified DMG read-only. Check the bundled app's version and signature before stopping the installed copy.
2. Quit `/Applications/Mana.app` and wait for its process to exit. Do not replace a running app.
3. Move the old app to a temporary backup, then copy the DMG app to `/Applications/Mana.app` with `ditto`.
4. Verify the installed version, code signature, and Gatekeeper assessment. Launch it and confirm its process is running.
5. If installation or launch fails, restore the backup and report the failure. Trash the backup only after verification succeeds.
6. Detach the DMG and remove the temporary mount directory. Do not touch Mana's credentials or settings.

## Report

Report the commit, tag, release URL, DMG path, and verification result. For a requested local replacement, report the installed version and running status. Include the DMG's SHA-256 when useful. State any remaining gate or local change that was left untouched.
