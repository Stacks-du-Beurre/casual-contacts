#!/bin/sh
set -eu

CONFIG_PATH="CasualContacts/Config/DeveloperSettingsUpload.xcconfig"

if [ -z "${CC_DEVELOPER_SETTINGS_UPLOAD_URL:-}" ] || [ -z "${CC_DEVELOPER_SETTINGS_UPLOAD_TOKEN:-}" ]; then
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
