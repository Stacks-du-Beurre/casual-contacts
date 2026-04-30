#!/usr/bin/env bash
# Cut a release: optionally bump MARKETING_VERSION, update
# CURRENT_PROJECT_VERSION (build number), commit, tag the resulting
# commit with `v-<name>`, and push.
#
# Branch-agnostic. Refuses to run on a dirty tree so the tag corresponds
# to a real, committed state we can later reproduce.
#
# Pass `--version X.Y.Z` when cutting a new marketing version (e.g. when
# moving from 1.0.2 to 1.0.3); this resets the build number to 1. Omit
# it to ship another build of the current marketing version, which bumps
# the build number by 1.
#
# Usage:
#   Tools/release.sh                            # bump build only, auto-name tag
#   Tools/release.sh some-name                  # bump build only, tag v-some-name
#   Tools/release.sh -v 1.0.3                   # bump marketing to 1.0.3 + reset build to 1, tag v-1.0.3
#   Tools/release.sh -v 1.0.3 rc1               # bump marketing + reset build to 1, tag v-rc1
#   Tools/release.sh -m "fixes save button"     # add an annotated tag message
#
# After running, the tag is pushed to origin so it's reachable from CI
# and other machines.
#
# To undo (only safe if no one's pulled the tag yet):
#   git push origin :refs/tags/<tag>
#   git tag -d <tag>
#   git reset --hard HEAD~1   # drop the version/build bump commit

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PBXPROJ="$REPO_ROOT/CasualContacts/CasualContacts.xcodeproj/project.pbxproj"

name=""
message=""
new_marketing=""
while [ $# -gt 0 ]; do
    case "$1" in
        --message|-m)
            shift
            message="${1:?--message requires a value}"
            ;;
        --version|-v)
            shift
            new_marketing="${1:?--version requires a value (e.g. 1.0.3)}"
            ;;
        -h|--help)
            sed -n '2,33p' "$0" | sed 's/^# \{0,1\}//'
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

if [ -n "$new_marketing" ] && ! [[ "$new_marketing" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
    echo "ERROR: --version must be X.Y or X.Y.Z (digits only); got '$new_marketing'" >&2
    exit 1
fi

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
    if [ -n "$new_marketing" ]; then
        # When cutting a marketing-version release, default the tag to v-<version>
        # so it's instantly recognizable (e.g. v-1.0.3) instead of a timestamp.
        name="$new_marketing"
    else
        safe_branch="$(echo "$branch" | tr '/' '-' | tr -cd '[:alnum:]-')"
        timestamp="$(date +%Y%m%d-%H%M)"
        name="${safe_branch}-${timestamp}"
    fi
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

current_marketing="$(grep -m1 'MARKETING_VERSION = ' "$PBXPROJ" | sed -E 's/.*MARKETING_VERSION = ([^;]+);.*/\1/')"

if [ -n "$new_marketing" ]; then
    if [ "$new_marketing" = "$current_marketing" ]; then
        echo "ERROR: MARKETING_VERSION is already $new_marketing. Omit --version to ship another build of the same marketing version." >&2
        exit 1
    fi
    marketing_version="$new_marketing"
    new_build=1
    echo "Bumping MARKETING_VERSION: $current_marketing → $new_marketing"
    sed -i '' "s/MARKETING_VERSION = [^;]*;/MARKETING_VERSION = $new_marketing;/g" "$PBXPROJ"
    if ! grep -q "MARKETING_VERSION = $new_marketing;" "$PBXPROJ"; then
        echo "ERROR: failed to update MARKETING_VERSION in pbxproj" >&2
        exit 1
    fi
else
    marketing_version="$current_marketing"
    new_build=$((current_build + 1))
fi

echo "Bumping CURRENT_PROJECT_VERSION: $current_build → $new_build (MARKETING_VERSION $marketing_version)"
sed -i '' "s/CURRENT_PROJECT_VERSION = [^;]*;/CURRENT_PROJECT_VERSION = $new_build;/g" "$PBXPROJ"

if ! grep -q "CURRENT_PROJECT_VERSION = $new_build;" "$PBXPROJ"; then
    echo "ERROR: failed to update CURRENT_PROJECT_VERSION in pbxproj" >&2
    exit 1
fi

git -C "$REPO_ROOT" add "$PBXPROJ"
if [ -n "$new_marketing" ]; then
    commit_subject="chore(release): bump to $new_marketing build $new_build for $tag"
else
    commit_subject="chore(release): bump build to $new_build for $tag"
fi
git -C "$REPO_ROOT" commit -m "$commit_subject"

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
