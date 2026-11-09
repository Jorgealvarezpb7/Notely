#!/usr/bin/env bash
set -euo pipefail

fail() {
    echo "error: $1" >&2
    exit 1
}

version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Packaging/Info.plist)
tag="v$version"

# Every check runs before the build, so a refused release fails fast and
# leaves nothing behind.
branch=$(git branch --show-current)
[[ "$branch" == "main" ]] || fail "releases must run from main, not '$branch'"

status=$(git status --porcelain)
[[ -z "$status" ]] || fail "working tree is not clean"

git fetch origin main || fail "could not fetch main from origin"

# Being ahead is refused too: the tag would publish commits not on origin.
[[ "$(git rev-parse HEAD)" == "$(git rev-parse origin/main)" ]] ||
    fail "main is not up to date with origin/main"

if git rev-parse --quiet --verify "refs/tags/$tag" >/dev/null; then
    fail "tag $tag already exists locally"
fi

remote_tag=$(git ls-remote --tags origin "refs/tags/$tag") || fail "could not list tags on origin"
[[ -z "$remote_tag" ]] || fail "tag $tag already exists on origin"

# Build before tagging so a failed build leaves no orphan tag.
just dmg

git tag "$tag"

git push origin "refs/tags/$tag"

if ! gh release create "$tag" Notely.dmg --generate-notes; then
    echo "error: tag $tag is pushed but the release was not created. Retry with:" >&2
    echo "  gh release create $tag Notely.dmg --generate-notes" >&2
    exit 1
fi
