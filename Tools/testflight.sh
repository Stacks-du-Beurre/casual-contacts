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
#
# Xcode Cloud upload-enabled builds require secret environment variables:
#   CC_DEVELOPER_SETTINGS_UPLOAD_URL
#   CC_DEVELOPER_SETTINGS_UPLOAD_TOKEN

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PBXPROJ="$REPO_ROOT/CasualContacts/CasualContacts.xcodeproj/project.pbxproj"
XCODE_CLOUD_POST_CLONE="$REPO_ROOT/CasualContacts/ci_scripts/ci_post_clone.sh"

compare_versions() {
    local left="$1"
    local right="$2"
    local left_major left_minor left_patch right_major right_minor right_patch
    IFS='.' read -r left_major left_minor left_patch <<< "$left"
    IFS='.' read -r right_major right_minor right_patch <<< "$right"
    left_patch="${left_patch:-0}"
    right_patch="${right_patch:-0}"

    if ((10#$left_major > 10#$right_major)); then
        printf '1\n'
    elif ((10#$left_major < 10#$right_major)); then
        printf -- '-1\n'
    elif ((10#$left_minor > 10#$right_minor)); then
        printf '1\n'
    elif ((10#$left_minor < 10#$right_minor)); then
        printf -- '-1\n'
    elif ((10#$left_patch > 10#$right_patch)); then
        printf '1\n'
    elif ((10#$left_patch < 10#$right_patch)); then
        printf -- '-1\n'
    else
        printf '0\n'
    fi
}

version_gt() {
    [ "$(compare_versions "$1" "$2")" = "1" ]
}

require_xcode_cloud_upload_config_script() {
    local relative_script="CasualContacts/ci_scripts/ci_post_clone.sh"

    if ! git -C "$REPO_ROOT" ls-files --error-unmatch "$relative_script" >/dev/null 2>&1; then
        echo "ERROR: $relative_script must be committed before tagging TestFlight builds." >&2
        echo "It writes DeveloperSettingsUpload.xcconfig from Xcode Cloud secret environment variables." >&2
        exit 1
    fi

    if [ ! -x "$XCODE_CLOUD_POST_CLONE" ]; then
        echo "ERROR: $relative_script must be executable. Run: chmod +x $relative_script" >&2
        exit 1
    fi

    if ! grep -q 'CC_DEVELOPER_SETTINGS_UPLOAD_URL' "$XCODE_CLOUD_POST_CLONE" ||
       ! grep -q 'CC_DEVELOPER_SETTINGS_UPLOAD_TOKEN' "$XCODE_CLOUD_POST_CLONE"; then
        echo "ERROR: $relative_script must write developer settings upload config from:" >&2
        echo "  CC_DEVELOPER_SETTINGS_UPLOAD_URL" >&2
        echo "  CC_DEVELOPER_SETTINGS_UPLOAD_TOKEN" >&2
        exit 1
    fi
}

highest_tagged_marketing_version() {
    local highest=""
    local tag version

    while IFS= read -r tag; do
        version="${tag#v-}"
        version="${version#v}"

        if [[ "$version" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
            if [ -z "$highest" ] || version_gt "$version" "$highest"; then
                highest="$version"
            fi
        fi
    done < <(git -C "$REPO_ROOT" tag --list 'v*')

    printf '%s\n' "$highest"
}

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

if [ ! -f "$PBXPROJ" ]; then
    echo "ERROR: pbxproj not found at $PBXPROJ" >&2
    exit 1
fi

require_xcode_cloud_upload_config_script

current_marketing="$(grep -m1 'MARKETING_VERSION = ' "$PBXPROJ" | sed -E 's/.*MARKETING_VERSION = ([^;]+);.*/\1/')"
if ! [[ "$current_marketing" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
    echo "ERROR: MARKETING_VERSION '$current_marketing' must be X.Y or X.Y.Z (digits only)." >&2
    exit 1
fi

latest_marketing="$(highest_tagged_marketing_version)"
if [ -n "$latest_marketing" ] && version_gt "$latest_marketing" "$current_marketing"; then
    echo "ERROR: MARKETING_VERSION $current_marketing is behind the latest release tag $latest_marketing. Bump to a new marketing version before tagging a TestFlight build." >&2
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

echo "Pushing $branch to origin (so the tagged commit is reachable)…"
git -C "$REPO_ROOT" push origin "$branch"

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
