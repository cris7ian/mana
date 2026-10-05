#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
cd "$ROOT"
DEVICE_ID="${MANA_SIMULATOR_ID:-$(xcrun simctl list devices available --json | python3 -c '
import json, sys
devices = json.load(sys.stdin)["devices"]
for runtime in sorted(devices, reverse=True):
    if "iOS" not in runtime:
        continue
    phones = [d for d in devices[runtime] if d.get("isAvailable") and d["name"].startswith("iPhone")]
    if phones:
        print(next((d for d in phones if d["name"] == "iPhone 17"), phones[0])["udid"])
        sys.exit(0)
sys.exit("Install an iOS simulator runtime in Xcode.")
')}"
mkdir -p build
DERIVED_DATA="${MANA_DERIVED_DATA_PATH:-build/ios-review}"
xcodebuild -quiet -project ios/ManaIOS.xcodeproj -scheme ManaIOS -configuration Debug \
  -destination "platform=iOS Simulator,id=$DEVICE_ID" -derivedDataPath "$DERIVED_DATA" \
  build CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=-
xcrun simctl bootstatus "$DEVICE_ID" -b
xcrun simctl install "$DEVICE_ID" "$DERIVED_DATA/Build/Products/Debug-iphonesimulator/Mana.app"
xcrun simctl launch --terminate-running-process "$DEVICE_ID" com.salsaparapizza.mana.ios --demo
open -a Simulator --args -CurrentDeviceUDID "$DEVICE_ID"
