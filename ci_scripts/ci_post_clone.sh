#!/bin/sh
set -eu

CONFIG_PATH="CasualContacts/Config/DeveloperSettingsUpload.xcconfig"
is_testflight_archive=false

workflow="$(printf '%s' "${CI_WORKFLOW:-}" | tr '[:upper:]' '[:lower:]')"
if [ "${CI_XCODE_CLOUD:-}" = "TRUE" ] && [ "${CI_XCODEBUILD_ACTION:-}" = "archive" ]; then
  case "$workflow" in
    *testflight*)
      is_testflight_archive=true
      ;;
  esac
fi

if [ "$is_testflight_archive" != "true" ]; then
  echo "Not an Xcode Cloud TestFlight archive; using empty upload defaults."
  exit 0
fi

case "${CC_DEVELOPER_SETTINGS_UPLOAD_URL:-}:${CC_DEVELOPER_SETTINGS_UPLOAD_TOKEN:-}" in
  :)
    echo "ERROR: TestFlight archives require Xcode Cloud secret environment variables:" >&2
    echo "  CC_DEVELOPER_SETTINGS_UPLOAD_URL" >&2
    echo "  CC_DEVELOPER_SETTINGS_UPLOAD_TOKEN" >&2
    exit 1
    ;;
  *:)
    echo "ERROR: TestFlight archives require Xcode Cloud secret environment variables:" >&2
    echo "  CC_DEVELOPER_SETTINGS_UPLOAD_TOKEN" >&2
    exit 1
    ;;
  :*)
    echo "ERROR: TestFlight archives require Xcode Cloud secret environment variables:" >&2
    echo "  CC_DEVELOPER_SETTINGS_UPLOAD_URL" >&2
    exit 1
    ;;
esac

mkdir -p "$(dirname "$CONFIG_PATH")"

upload_url="$(printf '%s\n' "$CC_DEVELOPER_SETTINGS_UPLOAD_URL" | sed 's,//,/$()/,g')"

cat > "$CONFIG_PATH" <<EOF
CC_DEVELOPER_SETTINGS_UPLOAD_URL = ${upload_url}
CC_DEVELOPER_SETTINGS_UPLOAD_TOKEN = ${CC_DEVELOPER_SETTINGS_UPLOAD_TOKEN}
EOF

echo "Developer settings upload config written for Xcode Cloud."
