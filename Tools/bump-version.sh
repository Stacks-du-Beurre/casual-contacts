#!/usr/bin/env bash
# Bump MARKETING_VERSION in the Xcode project, commit, and tag.
#
# Usage:
#   Tools/bump-version.sh <new-version>      # e.g. 1.0.1
#   Tools/bump-version.sh <new-version> beta # tags v1.0.1-beta instead of v1.0.1
#
# After running, push to trigger the Xcode Cloud workflow:
#   git push origin main --tags
#
# Tag conventions (match these to your Xcode Cloud workflow triggers):
#   v1.0.1        → App Store release workflow
#   v1.0.1-beta   → External TestFlight workflow

set -euo pipefail

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
    echo "Usage: $0 <new-version> [beta]" >&2
    echo "  e.g. $0 1.0.1" >&2
    echo "       $0 1.0.1 beta" >&2
    exit 1
fi

NEW_VERSION="$1"
TAG_SUFFIX="${2:-}"

if ! [[ "$NEW_VERSION" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
    echo "Error: version must be X.Y or X.Y.Z (digits only)" >&2
    exit 1
fi

if [ -n "$TAG_SUFFIX" ] && [ "$TAG_SUFFIX" != "beta" ]; then
    echo "Error: second arg, if provided, must be 'beta'" >&2
    exit 1
fi

TAG_NAME="v$NEW_VERSION"
[ -n "$TAG_SUFFIX" ] && TAG_NAME="$TAG_NAME-$TAG_SUFFIX"

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PBXPROJ="$REPO_ROOT/CasualContacts/CasualContacts.xcodeproj/project.pbxproj"

if [ ! -f "$PBXPROJ" ]; then
    echo "Error: pbxproj not found at $PBXPROJ" >&2
    exit 1
fi

if ! git -C "$REPO_ROOT" diff --quiet || ! git -C "$REPO_ROOT" diff --cached --quiet; then
    echo "Error: working tree is not clean. Commit or stash first." >&2
    exit 1
fi

if git -C "$REPO_ROOT" rev-parse "$TAG_NAME" >/dev/null 2>&1; then
    echo "Error: tag $TAG_NAME already exists" >&2
    exit 1
fi

CURRENT_VERSION=$(grep -m1 'MARKETING_VERSION = ' "$PBXPROJ" | sed -E 's/.*MARKETING_VERSION = ([^;]+);.*/\1/')

if [ "$CURRENT_VERSION" = "$NEW_VERSION" ]; then
    echo "Error: MARKETING_VERSION is already $NEW_VERSION" >&2
    exit 1
fi

echo "Bumping MARKETING_VERSION: $CURRENT_VERSION → $NEW_VERSION"
sed -i '' "s/MARKETING_VERSION = [^;]*;/MARKETING_VERSION = $NEW_VERSION;/g" "$PBXPROJ"

if ! grep -q "MARKETING_VERSION = $NEW_VERSION;" "$PBXPROJ"; then
    echo "Error: failed to update MARKETING_VERSION in pbxproj" >&2
    exit 1
fi

git -C "$REPO_ROOT" add "$PBXPROJ"
git -C "$REPO_ROOT" commit -m "chore(release): bump version to $NEW_VERSION"
git -C "$REPO_ROOT" tag -a "$TAG_NAME" -m "Release $NEW_VERSION"

echo
echo "Created commit and tag $TAG_NAME."
echo
echo "Next:"
echo "  git push origin main --tags"
echo
echo "To undo before pushing:"
echo "  git tag -d $TAG_NAME && git reset --hard HEAD~1"
