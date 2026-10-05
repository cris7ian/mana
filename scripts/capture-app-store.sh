#!/bin/zsh
# Use only a dedicated, credential-free simulator. All captured quotas are demo data.
set -euo pipefail
ROOT="${0:A:h:h}"
cd "$ROOT"
NAME="Mana App Store Assets"
DEVICE_ID="$(xcrun simctl list devices available --json | python3 -c '
import json, sys
for devices in json.load(sys.stdin)["devices"].values():
    for device in devices:
        if device["name"] == "Mana App Store Assets":
            print(device["udid"])
            sys.exit(0)
')"
if [[ -z "$DEVICE_ID" ]]; then
  RUNTIME="$(xcrun simctl list runtimes --json | python3 -c '
import json, sys
runtimes = [r for r in json.load(sys.stdin)["runtimes"] if r["isAvailable"] and r["name"].startswith("iOS") and int(r["version"].split(".")[0]) >= 26]
if not runtimes: sys.exit("Install an iOS 26 or later simulator runtime for iPhone 17 Pro Max.")
print(max(runtimes, key=lambda r: tuple(map(int, r["version"].split("."))))["identifier"])
')"
  DEVICE_ID="$(xcrun simctl create "$NAME" com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro-Max "$RUNTIME")"
fi
STATE="$(xcrun simctl list devices --json | python3 -c '
import json, sys
device_id = sys.argv[1]
print(next(d["state"] for devices in json.load(sys.stdin)["devices"].values() for d in devices if d["udid"] == device_id))
' "$DEVICE_ID")"
if [[ "$STATE" != Booted ]]; then xcrun simctl boot "$DEVICE_ID"; fi
xcrun simctl bootstatus "$DEVICE_ID" -b
xcrun simctl ui "$DEVICE_ID" appearance light
xcrun simctl status_bar "$DEVICE_ID" override --time '9:41' --dataNetwork wifi --wifiMode active --wifiBars 3 --batteryState charged --batteryLevel 100
STAMP="$(date +%Y%m%d-%H%M%S)"
RESULT="build/app-store-capture-$STAMP.xcresult"
EXPORT="build/app-store-attachments-$STAMP"
xcodebuild -quiet -project ios/ManaIOS.xcodeproj -scheme ManaIOS -configuration Debug \
  -destination "platform=iOS Simulator,id=$DEVICE_ID" -derivedDataPath build/app-store-capture \
  -parallel-testing-enabled NO -resultBundlePath "$RESULT" \
  -only-testing:ManaIOSUITests/ManaAppStoreScreenshotTests \
  test CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=-
xcrun xcresulttool export attachments --path "$RESULT" --output-path "$EXPORT"
python3 scripts/app-store-assets.py import-captures "$EXPORT"
python3 scripts/app-store-assets.py render
