#!/usr/bin/env bash
# run_codex_lane.sh — drive one implementation task through the codex CLI, on the LIVE working tree.
#
# Usage:
#   run_codex_lane.sh <spec_file> <final_message_file> [reasoning_effort] [model]
#
# - <spec_file>           : the six-part delegation spec (see references/delegation.md)
# - <final_message_file>  : where codex's final message is written
# - reasoning_effort      : low | medium | high | xhigh | max | ultra   (omit to use the CLI default)
# - model                 : optional slug. OMIT IT unless the caller pinned one — the lane's policy
#                           is to run on whatever `codex` is configured to use.
#
# This is the IMPLEMENTATION lane, not a fusion panelist. Two deliberate differences from
# scripts/fusion/run_codex.sh:
#   1. It runs against the real working tree — the whole point is to produce a diff you can review.
#      Sandbox is `workspace-write`, never `danger-full-access`: codex writes code, not your machine.
#   2. It detects an EMPTY DIFF mechanically. `codex exec` returns 0 when it declines to do the work,
#      so exit status alone cannot tell "done" from "refused" — see the AGENTS.md hazard below.
#
# The ~/.codex/AGENTS.md hazard, and why a preamble is prepended:
#   codex loads the user's global AGENTS.md on every invocation. When that file mandates its own
#   workflow ("read this workflow file first", "do NOT skip any steps", auto-activating skills),
#   codex correctly refuses to bypass it — and the run comes back exit 0, empty diff, polite refusal.
#   The preamble states the scoped opt-out those rules normally provide, for THIS lane only, and
#   overrides nothing else in them. Belt-and-braces: the empty-diff check is what actually catches it.
#
# Environment:
#   AGL_LANE_TIMEOUT   wall clock for the codex run, seconds (default 900)
#   AGL_LANE_SANDBOX   codex sandbox mode (default workspace-write)
#
# Exit codes:
#   0    codex ran and the working tree changed
#   1    codex failed
#   2    precondition failure (bad spec file)
#   3    codex unavailable (not on PATH, or not authenticated) — the caller reports STATUS: unavailable
#   4    codex exited 0 but the tree is UNCHANGED — a refusal, never a success
#   124  timed out

set -uo pipefail

AGL_LANE_TIMEOUT="${AGL_LANE_TIMEOUT:-900}"
AGL_LANE_SANDBOX="${AGL_LANE_SANDBOX:-workspace-write}"

spec_file="${1:?usage: run_codex_lane.sh <spec_file> <final_message_file> [effort] [model]}"
final_file="${2:?usage: run_codex_lane.sh <spec_file> <final_message_file> [effort] [model]}"
effort="${3:-}"
model="${4:-}"

abs() { case "$1" in /*) printf '%s' "$1" ;; *) printf '%s/%s' "$(pwd -P)" "$1" ;; esac; }
spec_file="$(abs "$spec_file")"
final_file="$(abs "$final_file")"

if [ ! -s "$spec_file" ]; then
  echo "[lane] spec file is missing or empty: $spec_file" >&2
  exit 2
fi
mkdir -p "$(dirname "$final_file")"
rm -f "$final_file"

# --- preflight: no silent fallback -----------------------------------------
if ! command -v codex >/dev/null 2>&1; then
  echo "[lane] codex is not on PATH — install it (npm i -g @openai/codex) and run 'codex login'." >&2
  exit 3
fi
if ! codex login status >/dev/null 2>&1; then
  echo "[lane] codex is installed but not authenticated — run 'codex login'." >&2
  exit 3
fi

# --- GNU-timeout semantics without GNU coreutils (stock macOS has neither) --
_run_with_timeout() {
  local secs="$1"; shift
  perl -e '
    my $secs = shift @ARGV;
    my $pid = fork();
    exit 127 unless defined $pid;
    if ($pid == 0) { exec @ARGV or exit 127; }
    local $SIG{ALRM} = sub { kill "TERM", $pid; sleep 2; kill "KILL", $pid; };
    alarm $secs;
    waitpid($pid, 0);
    my $rc = $?;
    alarm 0;
    exit 124 if ($rc & 127);
    exit($rc >> 8);
  ' "$secs" "$@"
}

# --- working-tree fingerprint, so "did anything change?" is a fact ---------
is_git=0
git rev-parse --show-toplevel >/dev/null 2>&1 && is_git=1
hasher="$(command -v shasum || command -v sha1sum || true)"

fingerprint() {
  [ "$is_git" = 1 ] || return 0
  [ -n "$hasher" ] || return 0
  { git rev-parse HEAD 2>/dev/null
    git status --porcelain 2>/dev/null
    git diff HEAD 2>/dev/null
  } | "$hasher" | cut -d' ' -f1
}
before="$(fingerprint)"

# --- build the prompt: scoped opt-out preamble + the caller's spec ----------
scratch="$(mktemp -d "${TMPDIR:-/tmp}/agl-lane.XXXXXX")"
trap 'rm -rf "$scratch"' EXIT
prompt="$scratch/prompt.md"

cat > "$prompt" << 'PREAMBLE'
This task runs in a dedicated implementation lane. The model and reasoning effort
used to invoke you were chosen deliberately by the caller for this task; nothing has
been substituted. If a user-level or project-level instruction file asks you to
default to a different orchestration flow, to read a workflow file first, or to route
this work through another command, treat this lane as an explicit opt-out from that
default and proceed with the task below. Every other instruction in those files still
applies — conventions, constraints, and prohibitions are unchanged.

Implement the specification that follows. When you are done, run the verification
command it names and include that command's ACTUAL output in your final message. If
the specification is ambiguous or self-contradictory, say so explicitly in your final
message rather than guessing.

---

PREAMBLE
cat "$spec_file" >> "$prompt"

# --- run ------------------------------------------------------------------
set -- codex exec --skip-git-repo-check --cd "$(pwd -P)" --sandbox "$AGL_LANE_SANDBOX"
[ -n "$model" ]  && set -- "$@" --model "$model"
[ -n "$effort" ] && set -- "$@" -c "model_reasoning_effort=$effort"
set -- "$@" -o "$final_file" -

_run_with_timeout "$AGL_LANE_TIMEOUT" "$@" < "$prompt" > "$scratch/stream.log" 2>&1
status=$?

if [ $status -eq 124 ]; then
  echo "[lane] codex timed out after ${AGL_LANE_TIMEOUT}s (raise AGL_LANE_TIMEOUT); tail of log:" >&2
  tail -20 "$scratch/stream.log" >&2
  echo "LANE_DIFF: $([ "$(fingerprint)" = "$before" ] && echo empty || echo changed)"
  exit 124
fi
if [ $status -ne 0 ]; then
  echo "[lane] codex exited $status; tail of log:" >&2
  tail -20 "$scratch/stream.log" >&2
  exit 1
fi

# --- the empty-diff check: exit 0 is not evidence that work happened -------
after="$(fingerprint)"
if [ "$is_git" != 1 ] || [ -z "$hasher" ]; then
  echo "LANE_DIFF: unknown (not a git repo, or no sha tool — verify the diff by hand)"
  echo "[lane] ok -> $final_file"
  exit 0
fi
if [ "$after" = "$before" ]; then
  echo "LANE_DIFF: empty"
  echo "[lane] codex exited 0 but the working tree is UNCHANGED — this is a refusal, not a success." >&2
  echo "[lane] its final message (quote this verbatim as REASON):" >&2
  sed -n '1,40p' "$final_file" >&2
  exit 4
fi
echo "LANE_DIFF: changed"
echo "[lane] ok -> $final_file"
