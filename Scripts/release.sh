#!/bin/bash
# Explicitly invoked by the maintainer; never called by build or test scripts.
set -euo pipefail
MACCLEAN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$MACCLEAN_ROOT"
if [[ $# -gt 1 ]] || { [[ $# -eq 1 ]] && [[ "$1" != --dry-run ]]; }; then
    printf 'Usage: Scripts/release.sh [--dry-run]\n' >&2
    exit 2
fi
tag=$(bash Scripts/version.sh --tag)
if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
    printf 'No Git repository found. Commit this project to a GitHub repository before releasing.\n' >&2
    exit 1
fi
if [[ "$(git branch --show-current)" != main ]]; then
    printf 'Release from the main branch.\n' >&2
    exit 1
fi
if [[ -n "$(git status --porcelain)" ]]; then
    printf 'Commit or stash changes before releasing.\n' >&2
    exit 1
fi
git remote get-url origin >/dev/null
if git show-ref --verify --quiet "refs/tags/$tag"; then
    printf '%s already exists. Update Config/Version.xcconfig first.\n' "$tag" >&2
    exit 1
fi
remote_tag=$(git ls-remote --tags origin "refs/tags/$tag")
if [[ -n "$remote_tag" ]]; then
    printf '%s already exists on origin. Update Config/Version.xcconfig first.\n' "$tag" >&2
    exit 1
fi

if [[ "${1:-}" == --dry-run ]]; then
    printf 'Checks passed. No tag or push performed.\nWould run tests, create %s, then:\n' "$tag"
    printf 'git push --atomic origin HEAD:refs/heads/main refs/tags/%s\n' "$tag"
    exit 0
fi

head=$(git rev-parse HEAD)
bash Scripts/test.sh
if [[ "$(git rev-parse HEAD)" != "$head" ]] || [[ -n "$(git status --porcelain)" ]]; then
    printf 'Repository changed during testing. Commit changes and retry.\n' >&2
    exit 1
fi
git tag -a "$tag" -m "MacClean $tag" "$head"
if ! git push --atomic origin HEAD:refs/heads/main "refs/tags/$tag"; then
    git tag -d "$tag" >/dev/null
    printf 'Push failed; removed local %s. Check origin before retrying.\n' "$tag" >&2
    exit 1
fi
printf '\nPushed %s. GitHub Actions will test, build and publish MacClean.dmg + SHA-256.\n' "$tag"
