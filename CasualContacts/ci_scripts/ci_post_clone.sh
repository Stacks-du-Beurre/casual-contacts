#!/bin/sh
set -eu

if [ -n "${CI_PROJECT_FILE_PATH:-}" ]; then
  PROJECT_DIR="$(cd "$(dirname "$CI_PROJECT_FILE_PATH")" && pwd)"
else
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
fi

CONFIG_PATH="$PROJECT_DIR/Config/DeveloperSettingsUpload.xcconfig"
is_testflight_archive=false

if [ "${CI_XCODE_CLOUD:-}" = "TRUE" ] && [ "${CI_WORKFLOW:-}" = "Development TestFlight" ]; then
  case "${CI_BRANCH:-}" in
    dev/?*) ;;
    *) echo "ERROR: Development TestFlight requires a dev/* branch." >&2; exit 1 ;;
  esac
  if [ "${CI_XCODEBUILD_ACTION:-}" = "archive" ]; then
    # Apple closes a marketing-version train after approval. Use the next
    # patch version for development archives, only in the cloud checkout.
    project_file="$PROJECT_DIR/CasualContacts.xcodeproj/project.pbxproj"
    next_version="$(awk '
      $1 == "MARKETING_VERSION" {
        version = $3
        sub(/;$/, "", version)
        if (version !~ /^[0-9]+\.[0-9]+(\.[0-9]+)?$/) exit 1
        split(version, parts, ".")
        printf "%d.%d.%d", parts[1], parts[2], parts[3] + 1
        found = 1
        exit
      }
      END { if (!found) exit 1 }
    ' "$project_file")" || {
      echo "ERROR: could not calculate the next development marketing version." >&2
      exit 1
    }
    sed -E "s/(MARKETING_VERSION = )[^;]+;/\\1${next_version};/g" "$project_file" > "$project_file.tmp"
    mv "$project_file.tmp" "$project_file"
    echo "Development archive marketing version: $next_version (cloud checkout only)."
  fi
fi

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
