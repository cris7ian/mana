#!/usr/bin/env bash
# Build, sign, notarize, and package Mana for direct macOS distribution.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
team="${APPLE_TEAM_ID:-}"
profile="${NOTARY_PROFILE:-}"

if [[ ! "$team" =~ ^[A-Z0-9]{10}$ || -z "$profile" ]]; then
    echo "Set APPLE_TEAM_ID (10-character team ID) and NOTARY_PROFILE (Keychain profile name)." >&2
    exit 1
fi

# Match both the certificate type and team. Never use an Apple Development identity for a release.
identity="$(security find-identity -v -p codesigning | awk -v team="$team" '
    index($0, "\"Developer ID Application:") && index($0, "(" team ")") { print $2; exit }
')"
if [[ -z "$identity" ]]; then
    echo "No valid Developer ID Application signing identity for team $team in this Keychain." >&2
    exit 1
fi

output_dir="$root/build/distribution"
mkdir -p "$output_dir"
work="$(mktemp -d "$output_dir/.release.XXXXXX")"
cleanup() {
    if command -v trash >/dev/null 2>&1; then
        trash "$work"
    elif [[ -d "$HOME/.Trash" ]]; then
        mv "$work" "$HOME/.Trash/$(basename "$work")"
    else
        /bin/rm -r "$work"
    fi
}
trap cleanup EXIT

archive="$work/Mana.xcarchive"
xcodebuild -project "$root/Mana.xcodeproj" -scheme Mana -configuration Release \
    -destination 'generic/platform=macOS' -archivePath "$archive" archive \
    CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="$identity" DEVELOPMENT_TEAM="$team"

app="$archive/Products/Applications/Mana.app"
if [[ ! -d "$app" ]]; then
    echo "Archive does not contain Mana.app." >&2
    exit 1
fi
codesign --verify --deep --strict --verbose=2 "$app"
signature="$(codesign -dv --verbose=4 "$app" 2>&1)"
if [[ "$signature" != *"TeamIdentifier=$team"* || "$signature" != *"runtime"* ]]; then
    echo "App signature has the wrong team or lacks Hardened Runtime." >&2
    exit 1
fi

version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")"
if [[ ! "$version" =~ ^[0-9]+([.][0-9]+)*$ ]]; then
    echo "Invalid app version for distribution filename." >&2
    exit 1
fi
output="$output_dir/Mana-$version.dmg"
if [[ -e "$output" ]]; then
    echo "Output already exists: $output (move it before creating another release)." >&2
    exit 1
fi

stage="$work/stage"
mkdir "$stage"
ditto "$app" "$stage/Mana.app"
ln -s /Applications "$stage/Applications"
dmg="$work/Mana-$version.dmg"
hdiutil create -volname 'Mana' -srcfolder "$stage" -format UDZO "$dmg"
codesign --force --sign "$identity" --timestamp "$dmg"
codesign --verify --verbose=2 "$dmg"

xcrun notarytool submit "$dmg" --keychain-profile "$profile" --wait
xcrun stapler staple "$dmg"
xcrun stapler validate "$dmg"
spctl --assess --type open --context context:primary-signature --verbose=2 "$dmg"

mv "$dmg" "$output"
echo "Installable notarized image: $output"
