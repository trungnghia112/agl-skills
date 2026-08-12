#!/usr/bin/env bash
# _fusion_lib.sh — shared helpers for the Fusion panelist runners.
#
# Sourced (not executed) by run_codex.sh, run_gemini.sh and preflight.sh:
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   . "$SCRIPT_DIR/_fusion_lib.sh"
#
# Why this exists: macOS has no `timeout`/`gtimeout` (those ship with GNU coreutils,
# not installed here). _run_with_timeout reproduces GNU `timeout` semantics with a
# small self-contained perl fork+alarm wrapper: it sends SIGTERM on the deadline,
# then SIGKILL after a 2s grace, returns the command's real exit status, and returns
# 124 when the command was killed for running over time.

# Default per-panelist budget in seconds; override with FUSION_TIMEOUT.
# 600s (not 300) because real panelist runs — codex at xhigh especially — routinely need >300s;
# a 300s cap dropped GPT mid-run in testing. Raise further for heavy deep-research questions.
FUSION_TIMEOUT="${FUSION_TIMEOUT:-600}"

# Budget for the sandbox copy run_codex.sh makes *before* codex starts. Deliberately much
# smaller than FUSION_TIMEOUT: a copy that cannot finish in a minute will not finish at all,
# and the panelist should be dropped rather than hang the whole panel.
FUSION_COPY_TIMEOUT="${FUSION_COPY_TIMEOUT:-60}"
# Budget for the cheap "how big is this tree?" probe run before a non-git copy.
FUSION_PROBE_TIMEOUT="${FUSION_PROBE_TIMEOUT:-15}"
# Refuse to copy a non-git cwd holding at least this many (non-excluded) files.
FUSION_MAX_FILES="${FUSION_MAX_FILES:-20000}"
# Sweep leftover scratch dirs older than this many minutes (hard-killed runs skip the EXIT trap).
FUSION_SCRATCH_MAX_AGE_MIN="${FUSION_SCRATCH_MAX_AGE_MIN:-120}"

# Directories that are never worth copying into a throwaway panelist sandbox:
# rebuildable artifacts and dependency trees, which dominate both size and file count.
FUSION_HEAVY_DIRS="${FUSION_HEAVY_DIRS:-node_modules .next dist build target .venv __pycache__ .turbo .cache}"

have() { command -v "$1" >/dev/null 2>&1; }

# _run_with_timeout SECONDS cmd [args...]
# Exit status = the command's own status, or 124 if it was killed for timing out.
#
# NOTE: the wrapper signals its direct child only, not a process group. Commands passed as
# `bash -c '<pipeline>'` therefore *can* leave a grandchild running past the deadline. That is
# tolerable here — the callers only ever read the source tree and write into a scratch dir that
# is removed on exit — and the caller itself always returns promptly, which is the point.
_run_with_timeout() {
  local secs="$1"; shift
  perl -e '
    my $secs = shift @ARGV;
    my $pid = fork();
    exit 127 unless defined $pid;
    if ($pid == 0) { exec @ARGV or exit 127; }   # child: become the real command
    local $SIG{ALRM} = sub { kill "TERM", $pid; sleep 2; kill "KILL", $pid; };
    alarm $secs;
    waitpid($pid, 0);
    my $rc = $?;
    alarm 0;
    exit 124 if ($rc & 127);   # killed by a signal (our TERM/KILL) => timed out
    exit($rc >> 8);            # otherwise propagate the command exit code
  ' "$secs" "$@"
}

# ---------------------------------------------------------------------------
# Source-root resolution (shared by run_codex.sh and preflight.sh)
# ---------------------------------------------------------------------------

# _fusion_resolve_source_root
# Sets, from the current directory:
#   FUSION_SOURCE_ROOT_RESOLVED  the directory a panelist sandbox would be built from
#   FUSION_SOURCE_SUBDIR         cwd relative to that root ("" when at the root)
#   FUSION_SOURCE_MODE           explicit | git | cwd
# Returns non-zero only when an explicit FUSION_SOURCE_ROOT is unusable.
_fusion_resolve_source_root() {
  local current_dir root=""
  current_dir="$(pwd -P)"
  FUSION_SOURCE_SUBDIR=""

  if [ -n "${FUSION_SOURCE_ROOT:-}" ]; then
    root="$(cd "$FUSION_SOURCE_ROOT" 2>/dev/null && pwd -P)"
    if [ -z "$root" ]; then
      echo "[fusion] FUSION_SOURCE_ROOT is not a readable directory: $FUSION_SOURCE_ROOT" >&2
      return 1
    fi
    FUSION_SOURCE_MODE="explicit"
  elif root="$(git rev-parse --show-toplevel 2>/dev/null)" && [ -n "$root" ]; then
    root="$(cd "$root" && pwd -P)"
    FUSION_SOURCE_MODE="git"
  else
    # Not a git repo: the root is just cwd, which may be an arbitrarily large parent
    # folder. Callers MUST probe it (see _fusion_probe_file_count) before copying.
    root="$current_dir"
    FUSION_SOURCE_MODE="cwd"
  fi

  case "$current_dir" in
    "$root")    FUSION_SOURCE_SUBDIR="" ;;
    "$root"/*)  FUSION_SOURCE_SUBDIR="${current_dir#"$root"/}" ;;
    *)          FUSION_SOURCE_SUBDIR="" ;;
  esac
  FUSION_SOURCE_ROOT_RESOLVED="$root"
}

# ---------------------------------------------------------------------------
# Exclude-list emitters. Each prints a single-quoted argument string meant to be
# embedded in a `bash -c` script, so the caller never has to worry about the glob
# characters being expanded against its own cwd.
# ---------------------------------------------------------------------------

_fusion_rsync_excludes() {   # rsync patterns without a slash match any path component
  local d out=""
  for d in $FUSION_HEAVY_DIRS "$@"; do out="$out --exclude='$d'"; done
  printf '%s' "$out"
}

_fusion_tar_excludes() {     # both forms, because bsdtar anchors --exclude and GNU tar does not
  local d out=""
  for d in $FUSION_HEAVY_DIRS "$@"; do out="$out --exclude='./$d' --exclude='*/$d'"; done
  printf '%s' "$out"
}

_fusion_find_prune_expr() {  # e.g. -name 'node_modules' -o -name '.git'
  local d out=""
  for d in $FUSION_HEAVY_DIRS "$@"; do
    [ -n "$out" ] && out="$out -o"
    out="$out -name '$d'"
  done
  printf '%s' "$out"
}

# _fusion_probe_file_count <root> <cap> <timeout_secs>
# Prints how many files a copy of <root> would carry, counting no further than <cap>
# (heavy dirs and .git are pruned, matching what the copy would actually exclude).
# Exit 124 if even that bounded count could not finish — which is itself the answer.
#
# The count goes through a temp FILE rather than straight to stdout on purpose. Callers capture
# this with $(...), and _run_with_timeout only signals its direct child: on a timeout the killed
# `bash -c` leaves the tail of the pipeline alive, and if that tail held the command-substitution
# pipe open, $(...) would block on it for as long as the runaway `find` kept running — silently
# reinstating the very hang this is here to prevent.
_fusion_probe_file_count() {
  local root="$1" cap="$2" secs="$3" prune tmpf status
  prune="$(_fusion_find_prune_expr .git)"
  tmpf="$(mktemp "${TMPDIR:-/tmp}/fusion-probe.XXXXXX")"
  _run_with_timeout "$secs" bash -c \
    "find \"\$1\" \\( $prune \\) -prune -o -type f -print 2>/dev/null | head -n \"\$2\" | wc -l | tr -d ' ' > \"\$3\"" \
    _fusion_probe "$root" "$cap" "$tmpf"
  status=$?
  cat "$tmpf" 2>/dev/null
  rm -f "$tmpf"
  return $status
}

# _fusion_sweep_scratch <prefix>
# `trap ... EXIT` never fires for a hard-killed run, so old scratch dirs pile up in TMPDIR.
# Clear the ones too old to belong to a live run. Best effort, never fatal.
_fusion_sweep_scratch() {
  local prefix="$1" tmp="${TMPDIR:-/tmp}"
  # -maxdepth 1 keeps this cheap, but it still runs before every panelist — bound it anyway so
  # a pathological TMPDIR can never become a new way to hang the run.
  _run_with_timeout 10 bash -c \
    'find "$1" -maxdepth 1 -type d -name "$2.*" -mmin "+$3" -exec rm -rf {} + 2>/dev/null' \
    _fusion_sweep "$tmp" "$prefix" "$FUSION_SCRATCH_MAX_AGE_MIN" >/dev/null 2>&1
  return 0
}
