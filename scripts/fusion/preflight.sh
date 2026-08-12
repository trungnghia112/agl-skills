#!/usr/bin/env bash
# preflight.sh — pre-run, NON-BLOCKING sanity check the orchestrator shows before fanning out.
#
# Usage:
#   preflight.sh <slug> <prompt_file>
#
# Prints: a rough token/call estimate (so a heavy question doesn't surprise you) and a Codex
# cap reminder. It NEVER blocks — it only informs. Always exits 0.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/_fusion_lib.sh"

slug="${1:?usage: preflight.sh <slug> <prompt_file>}"
prompt_file="${2:?usage: preflight.sh <slug> <prompt_file>}"

case "$slug" in
  opus-gpt-gemini) n=3 ;;
  opus-gpt|opus-gemini|opus-opus)  n=2 ;;
  *)                           n=2 ;;
esac

words=0
[ -f "$prompt_file" ] && words="$(wc -w < "$prompt_file" | tr -d ' ')"
# ~1.3 tokens/word, very rough; output usually dwarfs input on deep questions.
in_tokens=$(( words * 4 / 3 ))

echo "preflight (informational — not a gate):"
echo "  panel        : $slug  ($n panelists + 1 Opus judge pass)"
echo "  prompt size  : ~${words} words (~${in_tokens} input tokens) sent to EACH of $n panelists"
echo "  note         : each panelist also generates a full answer, and the judge reads all $n;"
echo "                 real token cost is several× the input. Heavy deep-research questions are slow."
echo "  per-panelist timeout : ${FUSION_TIMEOUT:-600}s (override with FUSION_TIMEOUT)"

if command -v codex >/dev/null 2>&1; then
  echo "  codex (GPT) : installed — quota isn't readable non-interactively; if a run fails on"
  echo "                    cap, check '/status' inside codex. Panel degrades gracefully if it does."
else
  echo "  codex (GPT) : NOT installed — GPT panelist will be skipped."
fi

# The GPT panelist runs against a throwaway copy of your working tree. Show what would be
# copied and roughly what it costs, so an oversized source root is visible here rather than
# showing up later as a slow run. Informational only — never a gate.
case "$slug" in
  *gpt*)
    if [ "${FUSION_NO_COPY:-0}" = "1" ]; then
      echo "  gpt sandbox : FUSION_NO_COPY=1 — codex runs against the LIVE cwd and can write to it"
    elif _fusion_resolve_source_root; then
      root="$FUSION_SOURCE_ROOT_RESOLVED"
      echo "  gpt sandbox : copies $root  (source: $FUSION_SOURCE_MODE)"
      if git -C "$root" rev-parse --show-toplevel >/dev/null 2>&1; then
        echo "                git repo — copies tracked + untracked-not-ignored files only,"
        echo "                so .gitignore'd build artifacts cost nothing. Copy cap ${FUSION_COPY_TIMEOUT}s."
      else
        probe="$(_fusion_probe_file_count "$root" "$FUSION_MAX_FILES" 5)"
        probe_status=$?
        if [ $probe_status -eq 124 ]; then
          echo "                NOT a git repo, and too large to even count in 5s."
          echo "                run_codex.sh will REFUSE to copy it — cd into your project first,"
          echo "                or set FUSION_SOURCE_ROOT=<path>, or use FUSION_NO_COPY=1."
        elif [ -n "$probe" ] && [ "$probe" -ge "$FUSION_MAX_FILES" ] 2>/dev/null; then
          echo "                NOT a git repo, >= ${FUSION_MAX_FILES} files (excluding build dirs)."
          echo "                run_codex.sh will REFUSE to copy it — cd into your project first,"
          echo "                or set FUSION_SOURCE_ROOT=<path>, or use FUSION_NO_COPY=1."
        else
          echo "                NOT a git repo — plain copy of ~${probe:-?} files (build dirs excluded),"
          echo "                capped at ${FUSION_COPY_TIMEOUT}s; over that, GPT is dropped, not hung."
        fi
      fi
    else
      echo "  gpt sandbox : FUSION_SOURCE_ROOT is unusable — GPT panelist will fail fast (exit 2)"
    fi
    ;;
esac

exit 0
