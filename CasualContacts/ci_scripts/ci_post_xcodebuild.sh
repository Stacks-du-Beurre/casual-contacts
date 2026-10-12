#!/bin/sh
# Add source identity to internal development builds in TestFlight.
set -eu

if [ "${CI_XCODE_CLOUD:-}" != "TRUE" ] || [ "${CI_XCODEBUILD_ACTION:-}" != "archive" ]; then
  exit 0
fi
if [ "${CI_WORKFLOW:-}" != "Development TestFlight" ]; then
  exit 0
fi
case "${CI_BRANCH:-}" in
  dev/?*) ;;
  *) echo "ERROR: Development TestFlight requires a dev/* branch." >&2; exit 1 ;;
esac

PROJECT_DIR="$(cd "$(dirname "$CI_PROJECT_FILE_PATH")" && pwd)"
NOTES_DIR="$PROJECT_DIR/TestFlight"
commit="$(git -C "$PROJECT_DIR" rev-parse --short HEAD)"
subject="$(git -C "$PROJECT_DIR" log -1 --format=%s)"
mkdir -p "$NOTES_DIR"
cat > "$NOTES_DIR/WhatToTest.en-US.txt" <<EOF
Development build. Internal testing only.
Branch: $CI_BRANCH
Commit: $commit
Xcode Cloud build: ${CI_BUILD_NUMBER:-unknown}

$subject

Check the branch and commit before you install this build.
This build uses the same saved contacts as other Casual Contacts builds.
EOF
echo "Development TestFlight notes written."
