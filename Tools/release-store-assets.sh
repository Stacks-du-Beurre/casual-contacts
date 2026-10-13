#!/usr/bin/env bash
# Generate a complete localized screenshot set and upload draft store assets.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
: "${ASC_KEY_ID:?Missing App Store Connect key ID}"
: "${ASC_ISSUER_ID:?Missing App Store Connect issuer ID}"
: "${ASC_PRIVATE_KEY_BASE64:?Missing App Store Connect private key}"
export CC_RELEASE_SHA="$(git rev-parse HEAD)"
export CC_RELEASE_VERSION
CC_RELEASE_VERSION="$(awk '$1 == "MARKETING_VERSION" {gsub(/;/,"",$3);print $3;exit}' CasualContacts/CasualContacts.xcodeproj/project.pbxproj)"
export CC_STORE_SCREENSHOTS="$ROOT/build/store-screenshots"
rm -rf "$CC_STORE_SCREENSHOTS"
mkdir -p "$CC_STORE_SCREENSHOTS"
SIM_IDS=()
cleanup() {
  for id in "${SIM_IDS[@]}"; do
    xcrun simctl shutdown "$id" >/dev/null 2>&1 || true
    xcrun simctl delete "$id" >/dev/null 2>&1 || true
  done
}
trap cleanup EXIT
runtime="$(xcrun simctl list runtimes -j | python3 -c 'import json,sys; r=[r for r in json.load(sys.stdin)["runtimes"] if r["isAvailable"] and r["identifier"].startswith("com.apple.CoreSimulator.SimRuntime.iOS-")]; print(max(r,key=lambda r:tuple(map(int,r["version"].split("."))))["identifier"])')"
for device in "iPhone 17 Pro Max"; do
  type="$(xcrun simctl list devicetypes -j | python3 -c 'import json,sys; name=sys.argv[1]; print(next(x["identifier"] for x in json.load(sys.stdin)["devicetypes"] if x["name"]==name))' "$device")"
  id="$(xcrun simctl create "CC Store Screenshots $device" "$type" "$runtime")"
  SIM_IDS+=("$id")
  output="$ROOT/build/captures/$device"
  "$ROOT/Tools/generate-screenshots.sh" --device-id "$id" --appearance dark --output-dir "$output"
  for pair in en:en-US ru:ru uk:uk; do
    language="${pair%%:*}"; locale="${pair#*:}"
    mkdir -p "$CC_STORE_SCREENSHOTS/$locale"
    # Prefix filenames to retain the agreed storefront order.
    index=1
    for screen in 02-list 04-detail-iris 01-empty-state 05-create-step1 06-create-step2 03-list-sort-open; do
      sips -s format jpeg -s formatOptions 95 "$output/$language/dark/$screen.png" --out "$CC_STORE_SCREENSHOTS/$locale/$(printf '%02d' "$index")-$device-$screen.jpg" >/dev/null
      index=$((index + 1))
    done
  done
done
python3 Tools/validate-store-assets.py
bundle exec fastlane ios store_assets
