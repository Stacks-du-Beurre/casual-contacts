#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

WORK_REPO="$TMP_ROOT/work"
ORIGIN_REPO="$TMP_ROOT/origin.git"

mkdir -p "$WORK_REPO/Tools" \
    "$WORK_REPO/CasualContacts/CasualContacts.xcodeproj" \
    "$WORK_REPO/marketing-site"

cp "$REPO_ROOT/Tools/release.sh" "$WORK_REPO/Tools/release.sh"
cp "$REPO_ROOT/CasualContacts/CasualContacts.xcodeproj/project.pbxproj" \
    "$WORK_REPO/CasualContacts/CasualContacts.xcodeproj/project.pbxproj"
cp "$REPO_ROOT/marketing-site/index.html" "$WORK_REPO/marketing-site/index.html"

/usr/bin/git init --bare "$ORIGIN_REPO" >/dev/null
/usr/bin/git -C "$WORK_REPO" init -b main >/dev/null
/usr/bin/git -C "$WORK_REPO" config user.name "Release Test"
/usr/bin/git -C "$WORK_REPO" config user.email "release-test@example.com"
/usr/bin/git -C "$WORK_REPO" remote add origin "$ORIGIN_REPO"
/usr/bin/git -C "$WORK_REPO" add .
/usr/bin/git -C "$WORK_REPO" commit -m "test fixture" >/dev/null

"$WORK_REPO/Tools/release.sh" --version 9.8.7 --message "test release" >/dev/null

if ! grep -q '<span class="nav-meta" data-app-version>v9.8.7</span>' "$WORK_REPO/marketing-site/index.html"; then
    echo "ERROR: release.sh did not update the marketing-site nav version to v9.8.7." >&2
    exit 1
fi

if grep -q 'v9.8.7.*build' "$WORK_REPO/marketing-site/index.html"; then
    echo "ERROR: marketing-site version display includes a build number." >&2
    exit 1
fi

if ! /usr/bin/git -C "$WORK_REPO" show --name-only --format= HEAD | grep -q '^marketing-site/index.html$'; then
    echo "ERROR: release commit did not include marketing-site/index.html." >&2
    exit 1
fi

"$WORK_REPO/Tools/release.sh" --build-only --message "test build-only release" >/dev/null

if ! grep -q '<span class="nav-meta" data-app-version>v9.8.7</span>' "$WORK_REPO/marketing-site/index.html"; then
    echo "ERROR: build-only release changed the marketing-site app version." >&2
    exit 1
fi

if /usr/bin/git -C "$WORK_REPO" show --name-only --format= HEAD | grep -q '^marketing-site/index.html$'; then
    echo "ERROR: build-only release commit included marketing-site/index.html." >&2
    exit 1
fi
