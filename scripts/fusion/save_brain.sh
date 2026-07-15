#!/usr/bin/env bash
# save_brain.sh — mirror one Fusion provenance file into the PROJECT brain (.agl/), agl-native.
#
# This is the agl "brain provenance" layer on top of the upstream save_run.sh. save_run.sh writes the
# canonical, timestamped record to the global ~/.claude/fusion-runs/ (audit trail, survives repo moves).
# save_brain.sh additionally drops a copy inside THIS project's brain so a fusion run travels with the
# project and shows up in /agl-recap — but ONLY when a .agl/ brain exists here. It never creates a brain.
#
# Usage:
#   save_brain.sh <global_run_md> [slug]
#
# - <global_run_md> : the path printed by save_run.sh (the canonical provenance .md)
# - slug            : optional panel slug, only used in the log line
#
# Behavior:
#   - Finds the project root (git top-level, else CWD).
#   - If <root>/.agl/ exists: copies the run .md to <root>/.agl/fusion-runs/, appends a conforming
#     `## HH:MM — fusion run` entry (brain-format.md grammar) to the day's session log, and prints
#     "BRAIN=<copied path>".
#   - If no .agl/ brain: prints "BRAIN=(none)" and exits 0 — never a gate, never an error.
#
# It NEVER blocks and always exits 0: a fusion answer must never fail because brain upkeep hiccuped.
# It does NOT touch STATE.md — that stays a deliberate Claude edit (see references/fusion.md), because
# STATE is curated, not appended to mechanically.

set -uo pipefail

run_md="${1:-}"
slug="${2:-fusion}"

if [ -z "$run_md" ] || [ ! -s "$run_md" ]; then
  echo "BRAIN=(none: no run file)"
  exit 0
fi

# Project root: git top-level if we're in a repo, else the current directory.
root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
[ -z "$root" ] && root="$(pwd -P)"

brain="$root/.agl"
if [ ! -d "$brain" ]; then
  echo "BRAIN=(none: no .agl brain in $root)"
  exit 0
fi

runs_dir="$brain/fusion-runs"
mkdir -p "$runs_dir" 2>/dev/null || { echo "BRAIN=(none: cannot write $runs_dir)"; exit 0; }

base="$(basename "$run_md")"
dest="$runs_dir/$base"
cp "$run_md" "$dest" 2>/dev/null || { echo "BRAIN=(none: copy failed)"; exit 0; }

# Append a conforming session entry to today's log (brain-format.md: `## HH:MM — <outcome>`
# heading + structured bullet). A leading blank line guarantees separation from any prior
# content — never graft onto or concatenate a previous entry. Append-only; safe if dir missing.
sessions_dir="$brain/sessions"
if mkdir -p "$sessions_dir" 2>/dev/null; then
  day="$(date +%Y-%m-%d)"
  when="$(date +%H:%M)"
  log="$sessions_dir/${day}.md"
  printf -- '\n## %s — fusion run (`%s`)\n- Evidence: panel provenance → `.agl/fusion-runs/%s`\n' \
    "$when" "$slug" "$base" >> "$log" 2>/dev/null || true
fi

echo "BRAIN=$dest"
exit 0
