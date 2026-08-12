#!/usr/bin/env bash
# run_codex.sh — run one GPT panelist (via codex) on a prompt, with web search + bash.
#
# Usage:
#   run_codex.sh <prompt_file> <output_file> [reasoning_effort]
#
# - <prompt_file>   : path to a file containing the FULL panelist prompt (verbatim user task + brief instruction)
# - <output_file>   : where the panelist's final answer is written (clean, just the answer)
# - reasoning_effort: low | medium | high | xhigh   (default: xhigh)
#
# Notes:
# - `-o/--output-last-message` writes ONLY the agent's final message — no streaming noise to parse.
# - The panelist runs against a temporary copy of the current repo/workdir, so its file writes do not
#   touch your live checkout.
# - `--dangerously-bypass-approvals-and-sandbox` intentionally gives the panelist the same local tool
#   access as a normal trusted Codex CLI run. This is needed for macOS keychain-backed tools like `gh`.
# - `-c tools.web_search=true` enables the web search tool.
# - The throwaway copy is deleted when the panelist exits; scratch dirs left behind by hard-killed
#   runs are swept at startup.
# - There is no `timeout`/`gtimeout` on stock macOS, so every long step is wrapped in a self-contained
#   perl timeout helper (see _fusion_lib.sh). BOTH the sandbox copy (FUSION_COPY_TIMEOUT, default 60s)
#   and the codex run itself (FUSION_TIMEOUT, default 600s) are bounded, so this script always returns
#   and the orchestrator can drop GPT and degrade the panel gracefully.
#
# How the sandbox is built, in order of preference:
#   1. FUSION_NO_COPY=1        — no sandbox at all; codex runs against the real cwd (it CAN write to it).
#   2. source root is a git repo — copy only `git ls-files` content (tracked + untracked-not-ignored),
#      so uncommitted edits come along and everything .gitignore'd is skipped for free. `.git` itself is
#      copied as a separate, bounded, best-effort step so the panelist still has history.
#   3. otherwise — plain filesystem copy with heavy dirs excluded (FUSION_HEAVY_DIRS), but only after a
#      bounded probe confirms the tree is not enormous. A non-git cwd holding >= FUSION_MAX_FILES files
#      is refused, not copied.
#
# Environment:
#   FUSION_TIMEOUT        codex budget in seconds (default 600)
#   FUSION_COPY_TIMEOUT   sandbox-copy budget in seconds (default 60)
#   FUSION_PROBE_TIMEOUT  tree-size probe budget in seconds (default 15)
#   FUSION_MAX_FILES      refuse to copy a non-git cwd with at least this many files (default 20000)
#   FUSION_SOURCE_ROOT    copy from this directory instead of auto-detecting
#   FUSION_NO_COPY=1      skip the sandbox entirely and run against the live cwd
#   FUSION_HEAVY_DIRS     space-separated dir names never copied
#
# Exit codes:
#   0    ok
#   1    codex failed, or produced no answer
#   2    precondition failure (bad prompt file, unusable source root, cwd too large to sandbox)
#   124  timed out — sandbox copy or codex run exceeded its budget

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/_fusion_lib.sh"

prompt_file="${1:?usage: run_codex.sh <prompt_file> <output_file> [reasoning_effort]}"
output_file="${2:?usage: run_codex.sh <prompt_file> <output_file> [reasoning_effort]}"
effort="${3:-xhigh}"

case "$prompt_file" in
  /*) ;;
  *) prompt_file="$(pwd -P)/$prompt_file" ;;
esac
case "$output_file" in
  /*) ;;
  *) output_file="$(pwd -P)/$output_file" ;;
esac

if [ ! -s "$prompt_file" ]; then
  echo "[run_codex.sh] prompt file is missing or empty: $prompt_file" >&2
  exit 2
fi
mkdir -p "$(dirname "$output_file")"
rm -f "$output_file"

_fusion_sweep_scratch fusion-codex

scratch="$(mktemp -d "${TMPDIR:-/tmp}/fusion-codex.XXXXXX")"
trap 'rm -rf "$scratch"' EXIT
workdir="$scratch/workdir"

# --- where would we copy from? ---------------------------------------------
if ! _fusion_resolve_source_root; then
  exit 2
fi
source_root="$FUSION_SOURCE_ROOT_RESOLVED"
source_subdir="$FUSION_SOURCE_SUBDIR"

source_is_git=0
if git -C "$source_root" rev-parse --show-toplevel >/dev/null 2>&1; then
  source_is_git=1
fi

# --- copy strategies (each bounded by FUSION_COPY_TIMEOUT) -----------------

# Working-tree copy driven by git: keeps uncommitted edits, drops ignored build artifacts.
# Files listed in the index but deleted on disk are filtered out so tar does not abort on them.
copy_git_aware() {
  _run_with_timeout "$FUSION_COPY_TIMEOUT" bash -c '
    set -uo pipefail
    cd "$1" || exit 1
    git ls-files -z --cached --others --exclude-standard \
      | while IFS= read -r -d "" f; do if [ -e "$f" ]; then printf "%s\0" "$f"; fi; done \
      | tar --null -T - -cf - \
      | tar -C "$2" -xf -
  ' _fusion_copy "$source_root" "$workdir"
}

# `.git` is copied on its own budget: it is often the heaviest part of a repo, and losing history
# is a far better outcome than hanging. A `.git` *file* (linked worktree/submodule) is skipped —
# it points at a gitdir outside the sandbox, which would defeat the isolation.
copy_git_dir() {
  [ -e "$source_root/.git" ] || return 0
  if [ ! -d "$source_root/.git" ]; then
    echo "[run_codex.sh] note: .git is a link to an external gitdir; panelist gets files, no history" >&2
    return 0
  fi
  _run_with_timeout "$FUSION_COPY_TIMEOUT" cp -R "$source_root/.git" "$workdir/.git"
  if [ $? -ne 0 ]; then
    rm -rf "$workdir/.git"
    echo "[run_codex.sh] warning: .git copy exceeded ${FUSION_COPY_TIMEOUT}s; panelist gets files, no history" >&2
    return 0
  fi
  rm -f "$workdir/.git/index.lock" "$workdir/.git/shallow.lock" "$workdir"/.git/worktrees/*/index.lock 2>/dev/null
  return 0
}

# Plain filesystem copy, heavy dirs excluded. `.git` is excluded here too — in a git repo it is
# handled by copy_git_dir, and under a non-git root any nested `.git` is dead weight.
copy_filesystem() {
  local excl
  if have rsync; then
    excl="$(_fusion_rsync_excludes .git)"
    _run_with_timeout "$FUSION_COPY_TIMEOUT" bash -c \
      "rsync -a $excl \"\$1\"/ \"\$2\"/" _fusion_copy "$source_root" "$workdir"
  else
    excl="$(_fusion_tar_excludes .git)"
    _run_with_timeout "$FUSION_COPY_TIMEOUT" bash -c \
      "set -o pipefail; tar -C \"\$1\" $excl -cf - . | tar -C \"\$2\" -xf -" \
      _fusion_copy "$source_root" "$workdir"
  fi
}

copy_failed() {
  local status="$1" what="$2"
  if [ "$status" -eq 124 ]; then
    echo "[run_codex.sh] sandbox copy of $source_root exceeded ${FUSION_COPY_TIMEOUT}s ($what)." >&2
    echo "[run_codex.sh] Raise FUSION_COPY_TIMEOUT, narrow it with FUSION_SOURCE_ROOT=<path>," >&2
    echo "[run_codex.sh] or run with FUSION_NO_COPY=1 to use the live cwd directly." >&2
    exit 124
  fi
  echo "[run_codex.sh] sandbox copy failed ($what, exit $status)" >&2
  exit 1
}

# --- build the sandbox ------------------------------------------------------
panel_cwd=""
if [ "${FUSION_NO_COPY:-0}" = "1" ]; then
  panel_cwd="$(pwd -P)"
  echo "[run_codex.sh] FUSION_NO_COPY=1 — running against the LIVE cwd; the panelist can write to it" >&2
else
  mkdir -p "$workdir"

  if [ "$source_is_git" -eq 1 ]; then
    copy_git_aware
    status=$?
    if [ $status -eq 124 ]; then
      copy_failed 124 "git-aware copy"
    elif [ $status -ne 0 ]; then
      # e.g. no usable tar — fall back to a plain copy rather than dropping the panelist
      echo "[run_codex.sh] git-aware copy failed (exit $status); falling back to filesystem copy" >&2
      copy_filesystem
      status=$?
      [ $status -ne 0 ] && copy_failed $status "filesystem copy"
    fi
    copy_git_dir
  else
    # Not a git repo: cwd may be an arbitrarily large parent folder full of unrelated projects.
    # Probe before committing to a copy, so the failure is an actionable message and not a hang.
    if [ "$FUSION_SOURCE_MODE" = "cwd" ]; then
      probe="$(_fusion_probe_file_count "$source_root" "$FUSION_MAX_FILES" "$FUSION_PROBE_TIMEOUT")"
      probe_status=$?
      if [ $probe_status -eq 124 ] || { [ -n "$probe" ] && [ "$probe" -ge "$FUSION_MAX_FILES" ] 2>/dev/null; }; then
        if [ $probe_status -eq 124 ]; then
          echo "[run_codex.sh] could not even count the files under $source_root in ${FUSION_PROBE_TIMEOUT}s." >&2
        else
          echo "[run_codex.sh] $source_root holds >= ${FUSION_MAX_FILES} files (excluding build dirs)." >&2
        fi
        echo "[run_codex.sh] cwd is not a git repo and looks very large; cd into your project first." >&2
        echo "[run_codex.sh] Or set FUSION_SOURCE_ROOT=<path>, raise FUSION_MAX_FILES, or use FUSION_NO_COPY=1." >&2
        exit 2
      fi
    fi
    copy_filesystem
    status=$?
    [ $status -ne 0 ] && copy_failed $status "filesystem copy"
  fi

  panel_cwd="$workdir"
  if [ -n "$source_subdir" ] && [ -d "$workdir/$source_subdir" ]; then
    panel_cwd="$workdir/$source_subdir"
  fi
fi

if command -v gh >/dev/null 2>&1; then
  if gh auth status --active --hostname github.com >/dev/null 2>&1; then
    echo "[run_codex.sh] gh auth ok in parent environment" >&2
  else
    echo "[run_codex.sh] warning: gh auth is not usable in parent environment" >&2
  fi
fi

_run_with_timeout "$FUSION_TIMEOUT" codex exec \
  --skip-git-repo-check \
  --ephemeral \
  --cd "$panel_cwd" \
  --dangerously-bypass-approvals-and-sandbox \
  -c tools.web_search=true \
  -c "model_reasoning_effort=$effort" \
  -o "$output_file" \
  - < "$prompt_file" \
  > "$scratch/stream.log" 2>&1

status=$?
if [ $status -eq 124 ]; then
  echo "[run_codex.sh] codex timed out after ${FUSION_TIMEOUT}s; tail of log:" >&2
  tail -20 "$scratch/stream.log" >&2
  exit 124
fi
if [ $status -ne 0 ] || [ ! -s "$output_file" ]; then
  echo "[run_codex.sh] codex exited $status; tail of log:" >&2
  tail -20 "$scratch/stream.log" >&2
  exit 1
fi
echo "[run_codex.sh] ok -> $output_file"
