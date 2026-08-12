#!/usr/bin/env bash
# release.sh — publish the current plugin version to the marketplace.
#
# This repo IS the Claude Code marketplace: .claude-plugin/marketplace.json sources
# from `github: trungnghia112/agl-skills` with NO version pin, so pushing `main`
# plus the `vX.Y.Z` tag is *exactly* what publishes a release. There is no separate
# registry to update — this script is the whole "update the marketplace" step.
#
# It releases the version ALREADY written in .claude-plugin/plugin.json — it does
# NOT bump it (major/minor/patch is a per-change decision). Idempotent: re-running
# after a release just re-pushes (a no-op on the remote).
#
#   bash scripts/release.sh            # tag v<version> + push main + tag
#   DRY_RUN=1 bash scripts/release.sh  # preview only — touches nothing
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
dry="${DRY_RUN:-}"

# A release is the moment the version number reaches users, so validate before
# tagging — not after. Runs on DRY_RUN too, so a preview tells you the truth.
if ! bash scripts/validate.sh; then
  echo
  echo "ERROR: validation failed — nothing tagged or pushed."
  exit 1
fi
echo

ver="$(python3 -c 'import json;print(json.load(open(".claude-plugin/plugin.json"))["version"])')"
[ -n "$ver" ] || { echo "ERROR: no version in .claude-plugin/plugin.json"; exit 1; }
tag="v$ver"
branch="$(git rev-parse --abbrev-ref HEAD)"

# Decide whether the tag needs creating. If it exists it MUST be at HEAD (already
# released) — otherwise the version wasn't bumped for this release.
make_tag=1
if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
  if [ "$(git rev-parse "$tag^{commit}")" = "$(git rev-parse HEAD)" ]; then
    echo "· $tag already at HEAD — re-pushing (idempotent)."
    make_tag=0
  else
    echo "ERROR: $tag exists but not at HEAD — bump the version in .claude-plugin/plugin.json before releasing."
    exit 1
  fi
fi

echo "Release $tag  (branch '$branch' → origin)"
if [ -n "$dry" ]; then
  echo "DRY_RUN — would run:"
  [ "$make_tag" = 1 ] && echo "  git tag $tag"
  echo "  git push origin $branch"
  echo "  git push origin $tag"
  exit 0
fi

# A real release must be a committed state — no stray uncommitted changes.
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "ERROR: working tree not clean — commit the version bump first, then release."
  git status --short
  exit 1
fi

[ "$make_tag" = 1 ] && { git tag "$tag"; echo "· created $tag → $(git rev-parse --short HEAD)"; }
git push origin "$branch"
git push origin "$tag"
echo "✅ Released $tag — marketplace (this repo) now serves $ver."
git ls-remote --tags origin "$tag"
