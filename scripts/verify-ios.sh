#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
cd "$ROOT"
DESTINATION="${MANA_IOS_DESTINATION:-}"
if [[ -z "$DESTINATION" ]]; then
  DEVICE_ID="$(xcrun simctl list devices available --json | python3 -c '
import json, sys
devices = json.load(sys.stdin)["devices"]
for runtime in sorted(devices, reverse=True):
    if "iOS" not in runtime:
        continue
    for device in devices[runtime]:
        if device.get("isAvailable") and device["name"].startswith("iPhone"):
            print(device["udid"])
            sys.exit(0)
sys.exit("No available iPhone simulator. Install an iOS runtime in Xcode.")
')"
  DESTINATION="platform=iOS Simulator,id=$DEVICE_ID"
fi
mkdir -p build
xcodebuild -project ios/ManaIOS.xcodeproj -scheme ManaIOS -configuration Debug \
  -destination "$DESTINATION" -derivedDataPath build/ios -parallel-testing-enabled NO \
  test CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=-
