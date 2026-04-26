#!/usr/bin/env bash
# Trigger an Xcode Cloud TestFlight build from the current commit.
#
# Branch-agnostic: tags the current HEAD with `tf-<name>` (or
# `tf-<branch>-<timestamp>` if no name given) and pushes that tag to
# origin. The Xcode Cloud workflow whose Start Condition matches
# `tf-*` will pick it up and ship the build to internal TestFlight.
#
# Usage:
#   Tools/testflight.sh                          # auto-name from branch + timestamp
#   Tools/testflight.sh feature-x                # explicit name → tag tf-feature-x
#   Tools/testflight.sh --message "fixes login"  # add an annotated tag message
#
# After running, check the build's progress at:
#   https://appstoreconnect.apple.com  → TestFlight → Builds
# (Or watch the Xcode Cloud reports tab in Xcode.)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

name=""
message=""
while [ $# -gt 0 ]; do
    case "$1" in
        --message|-m)
            shift
            message="${1:?--message requires a value}"
            ;;
        -h|--help)
            sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        -*)
            echo "Unknown flag: $1" >&2; exit 1
            ;;
        *)
            if [ -z "$name" ]; then
                name="$1"
            else
                echo "Multiple names passed: $name and $1" >&2; exit 1
            fi
            ;;
    esac
    shift
done

# Refuse if the working tree is dirty — TestFlight builds should
# correspond to a real, committed state we can later reproduce.
if ! git -C "$REPO_ROOT" diff --quiet || ! git -C "$REPO_ROOT" diff --cached --quiet; then
    echo "ERROR: working tree is not clean. Commit or stash first so the TestFlight build matches a real commit." >&2
    exit 1
fi

if [ -z "$name" ]; then
    branch="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD)"
    # Sanitize branch name for tag use (slashes → dashes, drop weird chars)
    safe_branch="$(echo "$branch" | tr '/' '-' | tr -cd '[:alnum:]-')"
    timestamp="$(date +%Y%m%d-%H%M)"
    name="${safe_branch}-${timestamp}"
fi

tag="tf-$name"

if git -C "$REPO_ROOT" rev-parse "$tag" >/dev/null 2>&1; then
    echo "ERROR: tag $tag already exists. Pass a different name." >&2
    exit 1
fi

commit_sha="$(git -C "$REPO_ROOT" rev-parse --short HEAD)"
branch="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD)"

if [ -z "$message" ]; then
    message="TestFlight build from $branch ($commit_sha)"
fi

echo "Tagging $commit_sha on $branch as $tag"
git -C "$REPO_ROOT" tag -a "$tag" -m "$message"

echo "Pushing tag to origin…"
git -C "$REPO_ROOT" push origin "$tag"

cat <<EOF

Tag $tag pushed. Xcode Cloud should pick it up within a minute.

Watch progress:
  • Xcode → Report navigator (Cmd+9) → cloud icon
  • https://appstoreconnect.apple.com → TestFlight → Builds

To undo before Xcode Cloud picks it up:
  git push origin :refs/tags/$tag
  git tag -d $tag
EOF
