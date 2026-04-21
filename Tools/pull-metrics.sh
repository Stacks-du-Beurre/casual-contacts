#!/bin/bash
# Pull MetricKit payload JSON files out of the app sandbox into the repo so
# they can be read directly (by Claude or by you).
#
# MetricsCollector writes payloads to `Documents/MetricKit/*.json`. This script
# extracts them from either the booted simulator's app container or a
# connected physical device into `docs/research/metrics/`.
#
# Usage:
#   ./Tools/pull-metrics.sh                # auto-detect: prefer sim, fall back to device
#   ./Tools/pull-metrics.sh sim            # force booted simulator
#   ./Tools/pull-metrics.sh device <udid>  # specific device
#
# Tip: you can synthesize a fresh MetricKit payload during dev via Xcode:
#   Debug → Simulate MetricKit Payloads
# Then run this script to pull the resulting JSON.

set -euo pipefail

BUNDLE_ID="com.stacksdubeurre.CasualContacts"
DEST_DIR="$(cd "$(dirname "$0")/.." && pwd)/docs/research/metrics"
mkdir -p "$DEST_DIR"

SOURCE="${1:-auto}"
UDID="${2:-}"

pull_simulator() {
    local sim_id
    sim_id="$(xcrun simctl list devices booted | grep -oE '[A-F0-9-]{36}' | head -1 || true)"
    if [[ -z "$sim_id" ]]; then
        echo "no booted simulator. Boot one first: xcrun simctl boot <name>"
        return 1
    fi
    local container
    container="$(xcrun simctl get_app_container "$sim_id" "$BUNDLE_ID" data 2>/dev/null || true)"
    if [[ -z "$container" || ! -d "$container/Documents/MetricKit" ]]; then
        echo "no MetricKit payloads in simulator app container at $container/Documents/MetricKit"
        echo "did the app run since the last collection window? did MetricsCollector.shared.register() fire?"
        return 1
    fi
    echo "pulling from simulator $sim_id"
    cp -v "$container"/Documents/MetricKit/*.json "$DEST_DIR/" 2>/dev/null || {
        echo "no .json files in $container/Documents/MetricKit"; return 1;
    }
}

pull_device() {
    if [[ -z "$UDID" ]]; then
        UDID="$(xcrun xctrace list devices 2>&1 | awk -F'[()]' '/^[^=]/ && !/Simulator/ && /[A-F0-9-]{8}-[A-F0-9-]{16}/ {print $(NF-1); exit}')"
    fi
    if [[ -z "$UDID" ]]; then
        echo "no connected device found. plug in a device or pass: ./pull-metrics.sh device <udid>"
        return 1
    fi
    echo "pulling from device $UDID"
    xcrun devicectl device copy from \
        --device "$UDID" \
        --source "/Documents/MetricKit/" \
        --destination "$DEST_DIR" \
        --domain-type appDataContainer \
        --domain-identifier "$BUNDLE_ID" \
        --user mobile 2>&1 || {
        echo
        echo "if the copy failed: the app's Documents directory needs to be exposed."
        echo "easiest fix: enable iTunes File Sharing in Info.plist (UIFileSharingEnabled = YES)."
        return 1
    }
}

case "$SOURCE" in
    sim)    pull_simulator ;;
    device) pull_device ;;
    auto)
        pull_simulator || pull_device
        ;;
    *)
        echo "usage: $0 [sim|device|auto] [udid]"
        exit 1
        ;;
esac

echo
echo "payloads in: $DEST_DIR"
ls -la "$DEST_DIR" | tail -n +2
