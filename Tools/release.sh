#!/usr/bin/env bash
# Cut a release: tag the current HEAD with `v-<name>` and push.
#
# Branch-agnostic. Refuses to run on a dirty tree so the tag corresponds
# to a real, committed state we can later reproduce. Distinct from the
# `v<X.Y.Z>` namespace used by `bump-version.sh` for Xcode Cloud — `v-`
# tags are ad-hoc release snapshots that don't bump MARKETING_VERSION.
#
# Usage:
#   Tools/release.sh                          # auto-name from branch + timestamp
#   Tools/release.sh some-name                # explicit name → tag v-some-name
#   Tools/release.sh -m "fixes save button"   # add an annotated tag message
#
# After running, the tag is pushed to origin so it's reachable from CI
# and other machines.
#
# To undo (only safe if no one's pulled the tag yet):
#   git push origin :refs/tags/<tag>
#   git tag -d <tag>

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
            sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
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

if ! git -C "$REPO_ROOT" diff --quiet || ! git -C "$REPO_ROOT" diff --cached --quiet; then
    echo "ERROR: working tree is not clean. Commit or stash first so the release tag matches a real commit." >&2
    exit 1
fi

branch="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD)"
commit_sha="$(git -C "$REPO_ROOT" rev-parse --short HEAD)"

if [ -z "$name" ]; then
    safe_branch="$(echo "$branch" | tr '/' '-' | tr -cd '[:alnum:]-')"
    timestamp="$(date +%Y%m%d-%H%M)"
    name="${safe_branch}-${timestamp}"
fi

# Sanitize the supplied name the same way as the auto-name path so the
# resulting tag is always a valid git ref. Slashes become dashes; anything
# outside [A-Za-z0-9.-] is dropped.
safe_name="$(echo "$name" | tr '/' '-' | tr -cd '[:alnum:].-')"
if [ -z "$safe_name" ]; then
    echo "ERROR: name '$name' has no usable characters for a tag." >&2
    exit 1
fi

tag="v-$safe_name"

if git -C "$REPO_ROOT" rev-parse "$tag" >/dev/null 2>&1; then
    echo "ERROR: tag $tag already exists. Pass a different name." >&2
    exit 1
fi

if [ -z "$message" ]; then
    message="Release $tag from $branch ($commit_sha)"
fi

echo "Tagging $commit_sha on $branch as $tag"
git -C "$REPO_ROOT" tag -a "$tag" -m "$message"

echo "Pushing $branch to origin (so the tagged commit is reachable)…"
git -C "$REPO_ROOT" push origin "$branch"

echo "Pushing tag to origin…"
git -C "$REPO_ROOT" push origin "$tag"

cat <<EOF

Release $tag pushed.

To undo (only safe if it hasn't been consumed yet):
  git push origin :refs/tags/$tag
  git tag -d $tag
EOF
