#!/usr/bin/env bash
# validate.sh — gate the things that have actually broken in this repo before.
#
#   bash scripts/validate.sh
#
# Exits non-zero on the first category that fails, after printing every finding.
# Run by scripts/release.sh before it tags, so a release cannot ship a version
# number that disagrees with itself or a command that points at a missing file.
#
# Written in bash + python3 (not Node) to match what this repo already depends
# on — release.sh reads plugin.json the same way, and there is no package.json
# to hang a Node toolchain from.
#
# What it checks, and why each one exists:
#   1. manifests parse, and plugin.json / marketplace.json agree on the name
#   2. plugin.json version == the newest CHANGELOG entry  (three places now
#      carry the version; this is the one that catches a hand-edit drifting)
#   3. plugin.json version is not behind the newest vX.Y.Z tag
#   4. every command has frontmatter with a description
#   5. every ${CLAUDE_PLUGIN_ROOT}/references/*.md link resolves
#   6. no reference file is orphaned (nothing reads it)
#   7. no pinned model version in the live guidance surface — the policy is
#      that slugs name a family, never a version (this is the check that would
#      have caught the stale "Opus 4.8" shipped in v1.5.4)

set -uo pipefail
cd "$(git rev-parse --show-toplevel)"

fail=0
problem() { printf '  ✗ %s\n' "$1"; fail=1; }
section() { printf '\n%s\n' "$1"; }

# --- 1. manifests ----------------------------------------------------------
section "manifests"
plugin_name=""; plugin_ver=""; market_name=""; commands_dir=""
if ! plugin_json="$(python3 -c '
import json
d = json.load(open(".claude-plugin/plugin.json"))
print(d.get("name",""));print(d.get("version",""));print(d.get("commands",""))
' 2>&1)"; then
  problem ".claude-plugin/plugin.json does not parse: $plugin_json"
else
  plugin_name="$(sed -n 1p <<<"$plugin_json")"
  plugin_ver="$(sed -n 2p <<<"$plugin_json")"
  commands_dir="$(sed -n 3p <<<"$plugin_json")"
  [ -n "$plugin_ver" ] || problem "plugin.json has no version"
  [ -d "$commands_dir" ] || problem "plugin.json commands path does not exist: $commands_dir"
fi

if ! market_name="$(python3 -c '
import json
d = json.load(open(".claude-plugin/marketplace.json"))
p = d.get("plugins") or [{}]
print(p[0].get("name",""))
' 2>&1)"; then
  problem ".claude-plugin/marketplace.json does not parse: $market_name"
elif [ "$market_name" != "$plugin_name" ]; then
  problem "marketplace.json plugin name '$market_name' != plugin.json name '$plugin_name'"
fi
[ "$fail" = 0 ] && echo "  ✓ plugin.json + marketplace.json agree ($plugin_name $plugin_ver)"

# --- 2. version vs CHANGELOG ----------------------------------------------
section "version consistency"
if [ ! -f CHANGELOG.md ]; then
  problem "CHANGELOG.md is missing"
else
  latest_entry="$(grep -m1 -oE '^## \[[0-9]+\.[0-9]+\.[0-9]+\]' CHANGELOG.md | tr -d '#[] ')"
  if [ -z "$latest_entry" ]; then
    problem "CHANGELOG.md has no '## [X.Y.Z]' entry"
  elif [ "$latest_entry" != "$plugin_ver" ]; then
    problem "plugin.json is $plugin_ver but the newest CHANGELOG entry is $latest_entry"
  else
    echo "  ✓ plugin.json $plugin_ver matches the newest CHANGELOG entry"
  fi
fi

# --- 3. version vs newest tag ---------------------------------------------
newest_tag="$(git tag --list 'v[0-9]*' | sed 's/^v//' \
  | sort -t. -k1,1n -k2,2n -k3,3n | tail -1)"
if [ -z "$newest_tag" ]; then
  # Say so rather than passing quietly: a shallow CI checkout fetches no tags,
  # and a check that silently skips itself reads exactly like a check that passed.
  echo "  ! no vX.Y.Z tags visible — skipping the tag comparison"
  echo "    (in CI this means the checkout has no tags: use fetch-depth: 0)"
elif [ -n "$plugin_ver" ]; then
  if ! python3 -c '
import sys
cur = tuple(int(x) for x in sys.argv[1].split("."))
tag = tuple(int(x) for x in sys.argv[2].split("."))
sys.exit(0 if cur >= tag else 1)
' "$plugin_ver" "$newest_tag"; then
    problem "plugin.json $plugin_ver is BEHIND the newest tag v$newest_tag — bump before releasing"
  else
    echo "  ✓ plugin.json $plugin_ver >= newest tag v$newest_tag"
  fi
fi

# --- 4. command frontmatter -----------------------------------------------
section "commands"
n_cmd=0
for f in commands/*.md; do
  n_cmd=$((n_cmd + 1))
  [ "$(head -1 "$f")" = "---" ] || { problem "$f does not open with frontmatter"; continue; }
  head -5 "$f" | grep -q '^description:' || problem "$f frontmatter has no description:"
done
[ "$n_cmd" -gt 0 ] || problem "no command files found in commands/"
echo "  ✓ $n_cmd commands carry frontmatter with a description"

# --- 5 + 6. reference links ------------------------------------------------
section "references"
referenced="$(grep -rho 'references/[A-Za-z0-9_-]*\.md' commands/ | sort -u)"
for p in $referenced; do
  [ -f "$p" ] || problem "a command links $p, which does not exist"
done
for f in references/*.md; do
  grep -q "^$f$" <<<"$referenced" || problem "$f is never read by any command (orphan)"
done
echo "  ✓ $(wc -l <<<"$referenced" | tr -d ' ') reference links resolve, no orphans"

# --- 7. no pinned model versions ------------------------------------------
# The live guidance surface names model FAMILIES only, so upgrading a CLI's
# default silently upgrades us. CHANGELOG.md is exempt: it is a historical
# record, and history is allowed to name the version it shipped with.
section "de-versioned model names"
hits="$(grep -rnE '(Opus|Sonnet|Haiku|GPT|Gemini|Fable)[- ]?[0-9]+\.[0-9]+' \
  commands/ references/ README.md 2>/dev/null)"
if [ -n "$hits" ]; then
  while IFS= read -r line; do problem "pinned model version: $line"; done <<<"$hits"
else
  echo "  ✓ no pinned model versions in commands/, references/, README.md"
fi

# --- verdict ---------------------------------------------------------------
echo
if [ "$fail" = 0 ]; then
  echo "✅ validate: all checks passed"
else
  echo "❌ validate: fix the findings above before releasing"
fi
exit "$fail"
