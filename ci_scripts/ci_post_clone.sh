#!/bin/sh
set -eu

CONFIG_PATH="CasualContacts/Config/DeveloperSettingsUpload.xcconfig"
build_ref="${CI_TAG:-${CI_GIT_REF:-}}"
requires_upload_config=false

case "$build_ref" in
  tf-developer-settings-upload*|refs/tags/tf-developer-settings-upload*)
    requires_upload_config=true
    ;;
esac

if [ -z "${CC_DEVELOPER_SETTINGS_UPLOAD_URL:-}" ] || [ -z "${CC_DEVELOPER_SETTINGS_UPLOAD_TOKEN:-}" ]; then
  if [ "$requires_upload_config" = "true" ]; then
    echo "ERROR: developer settings upload verification builds require Xcode Cloud secret environment variables:" >&2
    if [ -z "${CC_DEVELOPER_SETTINGS_UPLOAD_URL:-}" ]; then
      echo "  CC_DEVELOPER_SETTINGS_UPLOAD_URL" >&2
    fi
    if [ -z "${CC_DEVELOPER_SETTINGS_UPLOAD_TOKEN:-}" ]; then
      echo "  CC_DEVELOPER_SETTINGS_UPLOAD_TOKEN" >&2
    fi
    exit 1
  fi

  echo "Developer settings upload secrets are not configured; using empty upload defaults."
  exit 0
fi

mkdir -p "$(dirname "$CONFIG_PATH")"

upload_url="$(printf '%s\n' "$CC_DEVELOPER_SETTINGS_UPLOAD_URL" | sed 's,//,/$()/,g')"

cat > "$CONFIG_PATH" <<EOF
CC_DEVELOPER_SETTINGS_UPLOAD_URL = ${upload_url}
CC_DEVELOPER_SETTINGS_UPLOAD_TOKEN = ${CC_DEVELOPER_SETTINGS_UPLOAD_TOKEN}
EOF

echo "Developer settings upload config written for Xcode Cloud."
