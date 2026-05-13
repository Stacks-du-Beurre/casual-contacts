#!/bin/sh
set -eu

CONFIG_PATH="CasualContacts/Config/DeveloperSettingsUpload.xcconfig"

if [ -z "${CC_DEVELOPER_SETTINGS_UPLOAD_URL:-}" ] || [ -z "${CC_DEVELOPER_SETTINGS_UPLOAD_TOKEN:-}" ]; then
  echo "Developer settings upload secrets are not configured; using empty upload defaults."
  exit 0
fi

mkdir -p "$(dirname "$CONFIG_PATH")"

cat > "$CONFIG_PATH" <<EOF
CC_DEVELOPER_SETTINGS_UPLOAD_URL = ${CC_DEVELOPER_SETTINGS_UPLOAD_URL}
CC_DEVELOPER_SETTINGS_UPLOAD_TOKEN = ${CC_DEVELOPER_SETTINGS_UPLOAD_TOKEN}
EOF

echo "Developer settings upload config written for Xcode Cloud."
