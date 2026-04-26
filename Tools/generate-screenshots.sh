#!/usr/bin/env bash
# Generate App Store screenshots for Casual Contacts.
#
# Runs the `ScreenshotTests` UI test class against iPhone 17 Pro Max (the
# 6.9" required size) twice — once for light appearance, once for dark.
# Each test attaches a named PNG to the xcresult bundle; this script
# extracts them into `Screenshots/<appearance>/<screen>.png`.
#
# Output layout:
#   Screenshots/
#     light/01-empty-state.png …
#     dark/01-empty-state.png …
#
# Usage:
#   Tools/generate-screenshots.sh                        # both appearances
#   Tools/generate-screenshots.sh --appearance dark      # only dark mode
#   Tools/generate-screenshots.sh --appearance light     # only light mode
#   Tools/generate-screenshots.sh --framed               # also produce
#       framed marketing variants alongside the raw PNGs (requires
#       fastlane — `brew install fastlane`). Framed files land at
#       Screenshots/<appearance>/<screen>_framed.png. Use the raw
#       (un-framed) PNGs for App Store Connect uploads, the framed
#       ones for the marketing site.
#   Tools/generate-screenshots.sh --framed --frame-color black
#       Override the device finish for framing. Default: silver.
#       Other common values: black, gold, rose_gold, space_gray,
#       white, natural_titanium, desert_titanium, white_titanium,
#       black_titanium. Frameit validates and lists valid options
#       if it doesn't recognize the value.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$REPO_ROOT/CasualContacts"
OUTPUT_DIR="$REPO_ROOT/Screenshots"
SIM_NAME="iPhone 17 Pro Max"
APPEARANCES=("light" "dark")

TMP_RESULTS_DIR="$(mktemp -d -t cc-screenshots)"
trap 'rm -rf "$TMP_RESULTS_DIR"' EXIT

appearance_filter=""
frame_screenshots=false
frame_color="silver"
while [ $# -gt 0 ]; do
    case "$1" in
        --appearance)
            shift
            case "$1" in
                light|dark) appearance_filter="$1" ;;
                *) echo "Unknown appearance: $1 (expected light or dark)" >&2; exit 1 ;;
            esac
            ;;
        --framed)
            frame_screenshots=true
            ;;
        --frame-color)
            shift
            if [ -z "${1:-}" ]; then
                echo "Missing value for --frame-color" >&2; exit 1
            fi
            frame_color="$1"
            ;;
        -h|--help)
            sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            echo "Unknown arg: $1" >&2
            exit 1
            ;;
    esac
    shift
done

if [ "$frame_screenshots" = "true" ] && ! command -v fastlane >/dev/null 2>&1; then
    echo "ERROR: --framed requires fastlane. Install with: brew install fastlane" >&2
    exit 1
fi

if ! xcrun simctl list devices available | grep -q "$SIM_NAME"; then
    echo "ERROR: simulator '$SIM_NAME' not available."
    echo "Install via Xcode → Settings → Platforms."
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

# Extracts each screenshot attachment from the xcresult and writes it as
# `<screen-name>.png` in the output dir. Uses `manifest.json` (produced by
# `xcrun xcresulttool export attachments`) to map UUID-named exports back
# to the human-readable name we set in `ScreenshotTests.capture(_:name:)`.
# That readable name takes the form `<screen>_<idx>_<random-uuid>.png` —
# we strip the trailing `_N_<uuid>` to recover `<screen>`.
extract_attachments() {
    local result_bundle="$1"
    local out_dir="$2"
    mkdir -p "$out_dir"

    local staging="$TMP_RESULTS_DIR/staging-$RANDOM"
    rm -rf "$staging"
    mkdir -p "$staging"

    xcrun xcresulttool export attachments \
        --path "$result_bundle" \
        --output-path "$staging" \
        >/dev/null

    local manifest="$staging/manifest.json"
    if [ ! -f "$manifest" ]; then
        echo "0"
        return
    fi

    local count
    count=$(/usr/bin/python3 - "$staging" "$out_dir" <<'PY'
import json, os, re, shutil, sys
staging, out_dir = sys.argv[1], sys.argv[2]
manifest_path = os.path.join(staging, "manifest.json")
with open(manifest_path) as f:
    items = json.load(f)
saved = 0
for item in items:
    for att in item.get("attachments", []):
        exported = att.get("exportedFileName", "")
        readable = att.get("suggestedHumanReadableName", "")
        if not exported.endswith(".png"):
            continue
        # Strip "<screen>_<idx>_<uuid>.png" → "<screen>.png"
        m = re.match(r"^(.+?)_\d+_[0-9A-Fa-f-]+\.png$", readable)
        screen = m.group(1) if m else os.path.splitext(readable)[0]
        if not screen:
            continue
        src = os.path.join(staging, exported)
        if not os.path.exists(src):
            continue
        dst = os.path.join(out_dir, f"{screen}.png")
        shutil.move(src, dst)
        saved += 1
print(saved)
PY
    )
    echo "${count:-0}"
}

for appearance in "${APPEARANCES[@]}"; do
    if [ -n "$appearance_filter" ] && [ "$appearance" != "$appearance_filter" ]; then
        continue
    fi

    out="$OUTPUT_DIR/$appearance"
    rm -rf "$out"
    mkdir -p "$out"

    result_bundle="$TMP_RESULTS_DIR/${appearance}.xcresult"
    rm -rf "$result_bundle"

    echo
    echo "=== $SIM_NAME — $appearance ==="
    echo "Output: $out"

    # Pass the appearance into the test runner via the `TEST_RUNNER_*`
    # env-var convention. xcodebuild strips the prefix and forwards the
    # value into the test process — the only reliable way to inject
    # config since the test runs in a separate process inside the
    # simulator (a clone, in fact). The test code reads
    # SCREENSHOT_APPEARANCE from ProcessInfo and pushes
    # `-AppearanceOverride <appearance>` onto the app's launchArguments.
    #
    # Don't bail on individual test failures — a flaky wait in one test
    # shouldn't lose the screenshots from the other five. Extract
    # whatever attachments did make it into the xcresult, warn after.
    (cd "$APP_DIR" && \
        TEST_RUNNER_SCREENSHOT_APPEARANCE="$appearance" \
        xcodebuild test \
            -scheme CasualContacts \
            -destination "platform=iOS Simulator,name=$SIM_NAME" \
            -only-testing:CasualContactsUITests/ScreenshotTests \
            -resultBundlePath "$result_bundle" \
            -quiet) || echo "Note: at least one test failed for $appearance — extracting whatever PNGs we did capture." >&2

    if [ ! -d "$result_bundle" ]; then
        echo "ERROR: no result bundle at $result_bundle. Build likely failed." >&2
        exit 1
    fi

    count="$(extract_attachments "$result_bundle" "$out")"
    echo "Extracted $count PNGs."
    if [ "$count" -lt 6 ]; then
        echo "Warning: expected 6 PNGs, got $count for $appearance." >&2
    fi

    if [ "$frame_screenshots" = "true" ]; then
        # frameit auto-detects the device by image dimensions, downloads
        # the matching frame PNG on first run, and writes <name>_framed.png
        # next to each input. Run from inside the appearance directory so
        # frameit picks up exactly these files. Pipe its output through a
        # filter so first-run "downloading frames…" noise stays quiet.
        echo "Framing screenshots ($frame_color)…"
        (cd "$out" && fastlane frameit "$frame_color" 2>&1 | grep -E "Framing|Created|Error|error" || true)
        framed_count=$(find "$out" -name "*_framed.png" 2>/dev/null | wc -l | tr -d ' ')
        echo "Framed $framed_count PNGs."
    fi
done

echo
echo "Done. PNGs in $OUTPUT_DIR/"
