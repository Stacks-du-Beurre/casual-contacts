#!/usr/bin/env bash
# Cut a release: bump CURRENT_PROJECT_VERSION (build number), commit,
# tag the resulting commit with `v-<name>`, and push.
#
# Branch-agnostic. Refuses to run on a dirty tree so the tag corresponds
# to a real, committed state we can later reproduce. Distinct from the
# `v<X.Y.Z>` namespace used by `bump-version.sh` for Xcode Cloud — `v-`
# tags are ad-hoc release snapshots that don't change MARKETING_VERSION,
# but they do bump the build number so every tagged commit has a unique,
# monotonically increasing CFBundleVersion. App Store Connect rejects
# uploads whose build number isn't strictly greater than any prior
# upload, so bumping here keeps every `v-` tag eligible for submission.
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
#   git reset --hard HEAD~1   # drop the build-bump commit

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PBXPROJ="$REPO_ROOT/CasualContacts/CasualContacts.xcodeproj/project.pbxproj"

name=""
message=""
while [ $# -gt 0 ]; do
    case "$1" in
        --message|-m)
            shift
            message="${1:?--message requires a value}"
            ;;
        -h|--help)
            sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'
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

if [ ! -f "$PBXPROJ" ]; then
    echo "ERROR: pbxproj not found at $PBXPROJ" >&2
    exit 1
fi

branch="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD)"

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

current_build="$(grep -m1 'CURRENT_PROJECT_VERSION = ' "$PBXPROJ" | sed -E 's/.*CURRENT_PROJECT_VERSION = ([^;]+);.*/\1/')"

if ! [[ "$current_build" =~ ^[0-9]+$ ]]; then
    echo "ERROR: CURRENT_PROJECT_VERSION '$current_build' is not a positive integer; release.sh expects a simple integer build number." >&2
    exit 1
fi

new_build=$((current_build + 1))
marketing_version="$(grep -m1 'MARKETING_VERSION = ' "$PBXPROJ" | sed -E 's/.*MARKETING_VERSION = ([^;]+);.*/\1/')"

echo "Bumping CURRENT_PROJECT_VERSION: $current_build → $new_build (MARKETING_VERSION $marketing_version)"
sed -i '' "s/CURRENT_PROJECT_VERSION = [^;]*;/CURRENT_PROJECT_VERSION = $new_build;/g" "$PBXPROJ"

if ! grep -q "CURRENT_PROJECT_VERSION = $new_build;" "$PBXPROJ"; then
    echo "ERROR: failed to update CURRENT_PROJECT_VERSION in pbxproj" >&2
    exit 1
fi

git -C "$REPO_ROOT" add "$PBXPROJ"
git -C "$REPO_ROOT" commit -m "chore(release): bump build to $new_build for $tag"

commit_sha="$(git -C "$REPO_ROOT" rev-parse --short HEAD)"

if [ -z "$message" ]; then
    message="Release $tag ($marketing_version build $new_build) from $branch ($commit_sha)"
fi

echo "Tagging $commit_sha on $branch as $tag"
git -C "$REPO_ROOT" tag -a "$tag" -m "$message"

echo "Pushing $branch to origin (so the tagged commit is reachable)…"
git -C "$REPO_ROOT" push origin "$branch"

echo "Pushing tag to origin…"
git -C "$REPO_ROOT" push origin "$tag"

cat <<EOF

Release $tag pushed (MARKETING_VERSION $marketing_version, build $new_build).

To undo (only safe if it hasn't been consumed yet):
  git push origin :refs/tags/$tag
  git tag -d $tag
  git reset --hard HEAD~1   # drop the build-bump commit
  git push origin $branch --force-with-lease   # only if the bump commit was already pushed
EOF
