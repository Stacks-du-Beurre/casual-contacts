#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

WORK_REPO="$TMP_ROOT/work"
ORIGIN_REPO="$TMP_ROOT/origin.git"

mkdir -p "$WORK_REPO/Tools" \
    "$WORK_REPO/CasualContacts/CasualContacts.xcodeproj" \
    "$WORK_REPO/CasualContacts/ci_scripts" \
    "$WORK_REPO/marketing-site"

cp "$REPO_ROOT/Tools/release.sh" "$WORK_REPO/Tools/release.sh"
cp "$REPO_ROOT/Tools/testflight.sh" "$WORK_REPO/Tools/testflight.sh"
cp "$REPO_ROOT/CasualContacts/ci_scripts/ci_post_clone.sh" "$WORK_REPO/CasualContacts/ci_scripts/ci_post_clone.sh"
cp "$REPO_ROOT/CasualContacts/CasualContacts.xcodeproj/project.pbxproj" \
    "$WORK_REPO/CasualContacts/CasualContacts.xcodeproj/project.pbxproj"
cp "$REPO_ROOT/marketing-site/index.html" "$WORK_REPO/marketing-site/index.html"

perl -0pi -e 's/CURRENT_PROJECT_VERSION = [^;]+;/CURRENT_PROJECT_VERSION = 10;/g; s/MARKETING_VERSION = [^;]+;/MARKETING_VERSION = 1.0.4;/g' \
    "$WORK_REPO/CasualContacts/CasualContacts.xcodeproj/project.pbxproj"
perl -0pi -e 's{(<span class="nav-meta" data-app-version>v)\d+\.\d+(?:\.\d+)?(</span>)}{$1 . "1.0.4" . $2}eg' \
    "$WORK_REPO/marketing-site/index.html"

/usr/bin/git init --bare "$ORIGIN_REPO" >/dev/null
/usr/bin/git -C "$WORK_REPO" init -b main >/dev/null
/usr/bin/git -C "$WORK_REPO" config user.name "Release Test"
/usr/bin/git -C "$WORK_REPO" config user.email "release-test@example.com"
/usr/bin/git -C "$WORK_REPO" remote add origin "$ORIGIN_REPO"
/usr/bin/git -C "$WORK_REPO" add .
/usr/bin/git -C "$WORK_REPO" commit -m "test fixture" >/dev/null
/usr/bin/git -C "$WORK_REPO" tag -a v-1.0.5 -m "previous app store release"

if "$WORK_REPO/Tools/testflight.sh" behind-marketing-version >/dev/null 2>&1; then
    echo "ERROR: testflight.sh tagged a build even though MARKETING_VERSION is behind the latest release tag." >&2
    exit 1
fi

if "$WORK_REPO/Tools/release.sh" --build-only --message "should fail" >/dev/null 2>&1; then
    echo "ERROR: build-only release succeeded even though MARKETING_VERSION is behind the latest release tag." >&2
    exit 1
fi

"$WORK_REPO/Tools/release.sh" --message "test auto release catches up to latest tag" >/dev/null

if ! grep -q 'MARKETING_VERSION = 1.0.6;' "$WORK_REPO/CasualContacts/CasualContacts.xcodeproj/project.pbxproj"; then
    echo "ERROR: release.sh did not advance default marketing version past the latest release tag." >&2
    exit 1
fi

if ! grep -q 'CURRENT_PROJECT_VERSION = 1;' "$WORK_REPO/CasualContacts/CasualContacts.xcodeproj/project.pbxproj"; then
    echo "ERROR: release.sh did not reset build number for the recovered marketing version." >&2
    exit 1
fi

if ! grep -q '<span class="nav-meta" data-app-version>v1.0.6</span>' "$WORK_REPO/marketing-site/index.html"; then
    echo "ERROR: release.sh did not update the marketing-site nav version to v1.0.6." >&2
    exit 1
fi

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
