#!/usr/bin/env bash
# Push a committed dev/* branch to the internal-only Xcode Cloud workflow.
# Usage: Tools/testflight-dev.sh [--dry-run]
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
dry_run=false
case "${1:-}" in
    --dry-run) dry_run=true ;;
    -h|--help)
        echo "Usage: Tools/testflight-dev.sh [--dry-run]"
        echo "Push a clean dev/* branch. No release or TestFlight tag is created."
        exit 0
        ;;
    "") ;;
    *) echo "ERROR: unknown option: $1" >&2; exit 1 ;;
esac
if [ "$#" -gt 1 ]; then
    echo "ERROR: too many arguments." >&2
    exit 1
fi

branch="$(git -C "$REPO_ROOT" symbolic-ref --quiet --short HEAD)" || {
    echo "ERROR: switch to a dev/* branch in a linked worktree first." >&2
    exit 1
}
case "$branch" in
    dev/?*) ;;
    *) echo "ERROR: development builds require a dev/* branch; current branch is $branch." >&2; exit 1 ;;
esac
if [ -n "$(git -C "$REPO_ROOT" status --porcelain)" ]; then
    echo "ERROR: commit or remove pending changes before you request a build." >&2
    exit 1
fi

commit="$(git -C "$REPO_ROOT" rev-parse --short HEAD)"
echo "Development TestFlight: $branch ($commit)"
if [ "$dry_run" = true ]; then
    echo "Dry run: push HEAD to origin refs/heads/$branch. No changes were made."
    exit 0
fi
git -C "$REPO_ROOT" push --set-upstream origin "HEAD:refs/heads/$branch"
echo "Branch pushed. Check the Development TestFlight workflow in App Store Connect."
echo "After processing, select the build in TestFlight and check its branch and commit notes."
