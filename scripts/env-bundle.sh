#!/usr/bin/env bash
# env-bundle — an AES-256 encrypted archive of a repo's gitignored `.env` files,
# committed into a PRIVATE repo so a fresh clone restores its whole configuration.
#
#   preflight           hard gates: PRIVATE repo, 7-Zip, env files ignored, archive committable
#   inventory           the gitignored env files that belong in the bundle
#   pack [FILE...]      pack (default: the whole inventory) with AES-256, then self-verify
#   verify              AES-256 method + right password opens + wrong password rejected
#   drift               archive contents vs inventory — the gap nothing else notices
#   list                what is inside the archive
#   restore [--force]   extract at the repo root; EXISTING files are skipped unless --force
#   readme              write secrets/README.md from the archive's real contents
#
# ENV_BUNDLE_EXCLUDE="path ..." declares env files deliberately left out.
#
# Password, in order: $ENV_BUNDLE_PASS, the shared store (auth-info/zip.env,
# searched UPWARDS from the repo root), then PASS_ZIP= in this repo's .env.bak.
# Never pass the password as an argument to this script.
set -uo pipefail

ARCHIVE="${ENV_BUNDLE_ARCHIVE:-secrets/env-bundle.zip}"
PASS_FILE="${ENV_BUNDLE_PASS_FILE:-.env.bak}"
# The SHARED store, searched upwards from the repo root. One password for every
# bundle in a workspace, held in a directory that is inside no git repository.
SHARED_PASS_REL="${ENV_BUNDLE_SHARED_PASS_REL:-auth-info/zip.env}"
# Env files deliberately NOT packed (machine-local overrides, a teammate's
# scratch config) — whitespace-separated paths. Drift is a hard failure, so the
# ONLY way to leave a live env file out of the bundle is to say so here. An
# undeclared gap stays loud; a declared one is reported and forgiven.
EXCLUDE="${ENV_BUNDLE_EXCLUDE:-}"

die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
warn() { printf 'WARN:  %s\n' "$*" >&2; }
ok()   { printf 'OK:    %s\n' "$*"; }

find_7z() {
  if   command -v 7zz >/dev/null 2>&1; then printf '7zz'
  elif command -v 7z  >/dev/null 2>&1; then printf '7z'
  else return 1; fi
}
SZ="$(find_7z || true)"
need_7z() {
  [ -n "$SZ" ] || die "7-Zip not found. macOS: brew install sevenzip | Debian/Ubuntu: apt install p7zip-full"
}

cd "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || die "not inside a git repository"

# A path that escapes the repo root. `-spf` stores paths verbatim, so `../x/.env`
# packs as `../x/.env` and `restore` writes it OUTSIDE the repo — over a file the
# owner never named. Rejected on the way in AND on the way out, because an archive
# packed by an older version can still carry one.
unsafe_path() {
  case "$1" in
    /*|..|../*|*/../*|*/..) return 0 ;;
  esac
  return 1
}

# --- password resolution -----------------------------------------------------
# Reads `PASS_ZIP=` or `PASSWORD=`: the shared file uses the second name, and a
# reader that knows only one fails with "no password" while it sits right there.
# `\r` is stripped — a file edited on Windows carries one, 7-Zip takes it as part
# of the password, and the archive then opens with a string nobody typed.
read_pass_file() {
  [ -f "$1" ] || return 1
  local p
  p="$(grep -m1 -E '^(PASS_ZIP|PASSWORD)=' "$1" 2>/dev/null | cut -d= -f2- | tr -d '\r')"
  [ -n "$p" ] || return 1
  printf '%s' "$p"
}

# Searched UPWARDS, not at a fixed `../auth-info`: a repo may sit one level under
# the workspace or three, and a path that works from one depth breaks at the next.
find_shared_pass_file() {
  local d; d="$(pwd)"
  while [ "$d" != "/" ]; do
    [ -f "$d/$SHARED_PASS_REL" ] && { printf '%s' "$d/$SHARED_PASS_REL"; return 0; }
    d="$(dirname "$d")"
  done
  return 1
}

get_pass() {
  [ -n "${ENV_BUNDLE_PASS:-}" ] && { printf '%s' "$ENV_BUNDLE_PASS"; return 0; }
  # The shared file comes BEFORE `.env.bak`, deliberately: it is the one place the
  # workspace's password lives, so when the two disagree the shared one is right
  # and the repo-local copy is a stale leftover.
  local shared
  if shared="$(find_shared_pass_file)"; then
    read_pass_file "$shared" && return 0
    warn "$shared exists but holds no PASSWORD= or PASS_ZIP= line"
  fi
  read_pass_file "$PASS_FILE" && return 0
  return 1
}

# Where the password came from, for the report. Same order as get_pass.
pass_source() {
  [ -n "${ENV_BUNDLE_PASS:-}" ] && { printf '$ENV_BUNDLE_PASS'; return 0; }
  local shared
  if shared="$(find_shared_pass_file)" && read_pass_file "$shared" >/dev/null; then
    printf '%s' "$shared"; return 0
  fi
  read_pass_file "$PASS_FILE" >/dev/null && { printf '%s' "$PASS_FILE"; return 0; }
  printf 'nowhere'
}

no_pass_help() {
  cat >&2 <<HELP
ERROR: no archive password found. Searched, in order:
  1. \$ENV_BUNDLE_PASS        (not set)
  2. $SHARED_PASS_REL   upwards from $(pwd)  -> not found
  3. $PASS_FILE               -> no PASS_ZIP= / PASSWORD= line

ASK THE OWNER where their password file is. Do NOT invent a password and do NOT
fall back to a default: a bundle packed with a password the team does not hold is
a bundle nobody can restore, and it looks fine until somebody tries.

Once they answer:
  echo 'PASSWORD=<their-password>' > <path>/$SHARED_PASS_REL     # the shared store
  ENV_BUNDLE_SHARED_PASS_REL=<other/path.env> bash \$EB pack     # a different name
  ENV_BUNDLE_PASS='<password>' bash \$EB pack                    # one-off, stored nowhere
HELP
  exit 1
}

# =============================================================================
cmd_preflight() {
  local fail=0

  # 1. PRIVATE repo. On a public one every key inside is already burned, and git
  #    history keeps the archive forever.
  if command -v gh >/dev/null 2>&1; then
    local vis
    vis="$(gh repo view --json visibility -q .visibility 2>/dev/null)"
    case "$vis" in
      PRIVATE|INTERNAL) ok "repo visibility: $vis" ;;
      PUBLIC) printf 'ERROR: repo is PUBLIC — do not commit an env bundle. Treat every key inside as leaked.\n' >&2; fail=1 ;;
      *) warn "gh could not read repo visibility — confirm manually that it is PRIVATE" ;;
    esac
  else
    warn "gh CLI not found — confirm manually that this repo is PRIVATE"
    git remote -v | head -2 >&2
  fi

  # 2. 7-Zip present.
  if [ -n "$SZ" ]; then ok "7-Zip binary: $SZ"
  else printf 'ERROR: no 7zz/7z. macOS: brew install sevenzip | Debian/Ubuntu: apt install p7zip-full\n' >&2; fail=1; fi

  # 3. env files must be IGNORED — asked of git, not grepped out of .gitignore.
  #    A textual check fails a repo whose rule is `.env*`, which is broader and
  #    correct; `git check-ignore` answers the question that actually matters.
  local probe missing=()
  for probe in .env .env.local .env.production; do
    git check-ignore -q "$probe" || missing+=("$probe")
  done
  if [ ${#missing[@]} -eq 0 ]; then
    ok "git ignores env files (probed: .env, .env.local, .env.production)"
  else
    printf 'ERROR: git does NOT ignore: %s — add `.env*` + `!.env.example` to .gitignore\n' "${missing[*]}" >&2
    fail=1
  fi
  git check-ignore -q .env.example \
    && warn ".env.example is gitignored too — it is meant to be committed; add '!.env.example'"

  # 4. No raw env file may already be TRACKED. If one is, it is in history, and
  #    the fix is rotating that secret at the provider, not deleting the file.
  local tracked
  tracked="$(git ls-files | grep -E '(^|/)\.env($|\.)' | grep -v '\.env\.example$')"
  if [ -n "$tracked" ]; then
    printf 'ERROR: raw env file(s) already TRACKED by git:\n%s\n' "$tracked" >&2
    printf '       These are in git history. Rotate those secrets at the provider.\n' >&2
    fail=1
  else
    ok "no raw env files tracked by git"
  fi

  # 5. The archive must be COMMITTABLE. A repo that ignores `secrets/` makes
  #    `git add secrets/env-bundle.zip` a silent no-op that still exits 0 — the
  #    bundle is packed, verified, reported, and never actually shipped.
  if git check-ignore -q "$ARCHIVE"; then
    printf 'ERROR: %s is gitignored — `git add` would silently do nothing and the bundle would never ship.\n' "$ARCHIVE" >&2
    printf '       Un-ignore it (e.g. `!%s`) or set ENV_BUNDLE_ARCHIVE to a committable path.\n' "$ARCHIVE" >&2
    fail=1
  else
    ok "$ARCHIVE is committable (not gitignored)"
  fi

  [ "$fail" -eq 0 ] || die "preflight FAILED — fix the above before packing"
  ok "preflight passed"
}

# =============================================================================
# The gitignored env files. Untracked-but-NOT-ignored ones are called out on
# stderr: they are about to be committed in the clear, which no other check sees.
cmd_inventory() {
  local loose
  loose="$(git ls-files --others --exclude-standard | grep -E '(^|/)\.env($|\.)' | grep -v '\.env\.example$')"
  [ -n "$loose" ] && warn "env file(s) NOT gitignored — they will be committed in the clear:"$'\n'"$loose"
  git ls-files --others --ignored --exclude-standard \
    | grep -E '(^|/)\.env($|\.)' \
    | grep -v '\.env\.example$' \
    | sort
}

# =============================================================================
cmd_pack() {
  need_7z
  local files=()
  if [ "$#" -gt 0 ]; then
    files=("$@")
  else
    # No arguments = the whole inventory. This is the default because the #1 way
    # this pattern fails is a NEW env file missing from a hand-typed list: the
    # pack succeeds, verify says VERIFIED, and the next clone is quietly short a
    # secret. An explicit list is still allowed — it just gets a drift report.
    # ENV_BUNDLE_EXCLUDE actually EXCLUDES here, not just in the drift report:
    # a knob whose name says "exclude" but only silences a warning packs the file
    # the owner asked to keep off the archive.
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      if [ -n "$EXCLUDE" ] && printf '%s\n' $EXCLUDE | grep -qxF "$f"; then
        printf '  (excluded: %s)\n' "$f"; continue
      fi
      files+=("$f")
    done < <(cmd_inventory)
    [ "${#files[@]}" -gt 0 ] || die "inventory found no gitignored env files to pack (after exclusions)"
    printf 'Packing the full inventory (%d file(s)):\n' "${#files[@]}"
    printf '  %s\n' "${files[@]}"
  fi

  local pass
  pass="$(get_pass)" || no_pass_help

  local f missing=0
  for f in "${files[@]}"; do
    unsafe_path "$f" && die "refusing to pack a path that escapes the repo root: $f"
    [ -f "$f" ] || { printf 'ERROR: no such file: %s\n' "$f" >&2; missing=1; continue; }
    git check-ignore -q "$f" || warn "$f is NOT gitignored — it could be committed in the clear"
  done
  [ "$missing" -eq 0 ] || die "aborting: listed file(s) missing"

  mkdir -p "$(dirname "$ARCHIVE")"
  rm -f "$ARCHIVE"

  # -mem=AES256 is MANDATORY: the -tzip default is ZipCrypto, which is broken.
  # -spf preserves relative paths so restore lands files back in place.
  "$SZ" a -tzip -mem=AES256 -mx=9 -p"$pass" -spf "$ARCHIVE" "${files[@]}" >/dev/null \
    || die "packing failed"
  ok "packed ${#files[@]} file(s) into $ARCHIVE"

  # Never leave an unverified archive on disk.
  if ! cmd_verify; then
    rm -f "$ARCHIVE"
    die "verification FAILED — bad archive deleted, nothing to commit"
  fi
  # The archive is cryptographically fine, so it is NOT deleted — but an
  # incomplete bundle is the failure this whole pattern exists to prevent, and a
  # note that scrolls past is not a gate. Exit non-zero and let the caller decide.
  cmd_drift || die "archive is VALID but INCOMPLETE — do not commit it until the drift above is resolved"
}

# =============================================================================
cmd_verify() {
  need_7z
  [ -f "$ARCHIVE" ] || die "archive not found: $ARCHIVE"
  local rc=0

  # 1 — encryption method must be AES-256, not ZipCrypto and not Store.
  local method
  method="$("$SZ" l -slt "$ARCHIVE" 2>/dev/null | grep -m1 '^Method = ')"
  if printf '%s' "$method" | grep -q 'AES-256'; then
    ok "encryption is AES-256  ($method)"
  else
    printf 'FAIL:  encryption is NOT AES-256 -> %s\n' "${method:-<none: archive may be unencrypted>}" >&2
    rc=1
  fi

  # 2 — the password we hold must actually open this archive.
  local pass
  if pass="$(get_pass)"; then
    if "$SZ" t -p"$pass" "$ARCHIVE" >/dev/null 2>&1; then
      ok "stored password opens the archive"
    else
      # Names the file the password ACTUALLY came from: the one message whose
      # whole job is to say where to look must not hard-code $PASS_FILE.
      printf 'FAIL:  the password in %s does NOT open %s\n' "$(pass_source)" "$ARCHIVE" >&2
      rc=1
    fi
  else
    warn "no password available — skipped the 'correct password works' check"
  fi

  # 3 — a wrong password must be rejected. If it passes, there is no encryption.
  if "$SZ" t -p"wrong-password-$$-$RANDOM" "$ARCHIVE" >/dev/null 2>&1; then
    printf 'FAIL:  a WRONG password opened the archive — it is not encrypted\n' >&2
    rc=1
  else
    ok "wrong password is rejected"
  fi

  [ "$rc" -eq 0 ] && printf 'VERIFIED: %s (%s entries, password from %s)\n' \
    "$ARCHIVE" "$(cmd_list | wc -l | tr -d ' ')" "$(pass_source)"
  return "$rc"
}

# =============================================================================
# Archive vs disk. A bundle can be perfectly encrypted and still be WRONG —
# missing the env file added last week. Nothing else in this script, and nothing
# in git, notices that; `verify` passes either way.
cmd_drift() {
  local inv arc missing extra
  inv="$(cmd_inventory 2>/dev/null)"
  arc="$(cmd_list)"
  missing="$(comm -23 <(printf '%s\n' "$inv" | sort -u) <(printf '%s\n' "$arc" | sort -u))"
  extra="$(comm -13 <(printf '%s\n' "$inv" | sort -u) <(printf '%s\n' "$arc" | sort -u))"

  # Declared exclusions are subtracted, and still printed: "we meant to leave
  # this out" has to stay visible, or it becomes "we forgot" six months later.
  if [ -n "$EXCLUDE" ]; then
    local declared
    declared="$(comm -12 <(printf '%s\n' $missing | sort -u) <(printf '%s\n' $EXCLUDE | sort -u))"
    [ -n "$declared" ] && {
      printf 'NOTE:  deliberately excluded (ENV_BUNDLE_EXCLUDE), not in the archive:\n' >&2
      printf '  %s\n' $declared >&2
    }
    missing="$(comm -23 <(printf '%s\n' $missing | sort -u) <(printf '%s\n' $EXCLUDE | sort -u))"
  fi

  if [ -n "$missing" ]; then
    printf 'DRIFT: on disk but NOT in the archive — a fresh clone restores an INCOMPLETE config:\n' >&2
    printf '  %s\n' $missing >&2
    printf '       Repack with no file list to take the whole inventory, or declare the\n' >&2
    printf '       omission: ENV_BUNDLE_EXCLUDE="<path>" — an undeclared gap is a failure.\n' >&2
  fi
  [ -n "$extra" ] && {
    printf 'NOTE:  in the archive but not on disk (renamed, deleted, or machine-local):\n' >&2
    printf '  %s\n' $extra >&2
  }
  [ -z "$missing" ] && { ok "no drift — archive matches the inventory"; return 0; }
  return 1
}

# =============================================================================
cmd_list() {
  need_7z
  [ -f "$ARCHIVE" ] || die "archive not found: $ARCHIVE"
  "$SZ" l -ba -slt "$ARCHIVE" 2>/dev/null | sed -n 's/^Path = //p'
}

# =============================================================================
cmd_restore() {
  need_7z
  [ -f "$ARCHIVE" ] || die "archive not found: $ARCHIVE"
  local force=0
  [ "${1:-}" = "--force" ] && force=1

  # Entries that escape the repo root are refused even when this script did not
  # pack them: an older bundle can carry `../x/.env`, and extracting it writes
  # over a file in a sibling directory that nobody agreed to.
  local entries unsafe=()
  entries="$(cmd_list)"
  while IFS= read -r e; do
    [ -n "$e" ] && unsafe_path "$e" && unsafe+=("$e")
  done <<<"$entries"
  [ "${#unsafe[@]}" -eq 0 ] || {
    printf 'ERROR: archive holds path(s) that escape the repo root — refusing to extract:\n' >&2
    printf '  %s\n' "${unsafe[@]}" >&2
    exit 1
  }

  # Which files are already here. `.env` files are GITIGNORED, so an overwrite is
  # not recoverable with `git checkout` — skipping by default is the only safe
  # behaviour, and the owner is told exactly what was left alone.
  local present=()
  while IFS= read -r e; do
    [ -n "$e" ] && [ -e "$e" ] && present+=("$e")
  done <<<"$entries"

  local mode='-aos'; [ "$force" = 1 ] && mode='-aoa'
  local pass
  if pass="$(get_pass)"; then
    "$SZ" x -p"$pass" "$mode" -y "$ARCHIVE" >/dev/null || die "extraction failed (wrong password?)"
  else
    # RESTORE is the one command that may run without a stored password: a human
    # is at the keyboard and 7-Zip prompts. `pack` must not — there the password
    # BECOMES the archive, and a wrong one is only discovered by the next person.
    warn "no stored password; 7-Zip will ask. Then put it in $SHARED_PASS_REL so the next restore does not have to."
    "$SZ" x "$mode" "$ARCHIVE" || die "extraction failed (wrong password?)"
  fi

  if [ "${#present[@]}" -gt 0 ] && [ "$force" = 0 ]; then
    warn "SKIPPED ${#present[@]} file(s) that already existed — local edits kept, NOT overwritten:"
    printf '  %s\n' "${present[@]}" >&2
    warn "re-run with --force to overwrite them with the archive's copy"
  elif [ "${#present[@]}" -gt 0 ]; then
    ok "--force: overwrote ${#present[@]} existing file(s)"
  fi
  ok "restored at $(pwd)"
  printf '%s\n' "$entries"
}

# =============================================================================
# secrets/README.md, generated from what is ACTUALLY in the archive. A template
# filled in by hand goes stale the first time the file list changes, and the
# person it misleads is the one restoring on a new machine.
cmd_readme() {
  local out; out="$(dirname "$ARCHIVE")/README.md"
  local entries; entries="$(cmd_list)"
  mkdir -p "$(dirname "$out")"
  {
    printf '# %s\n\n' "$(dirname "$ARCHIVE")"
    printf '`%s` is an **AES-256 encrypted** archive of this repo'"'"'s gitignored\n' "$ARCHIVE"
    printf 'env files, committed so a fresh clone can restore the whole configuration.\n\n'
    printf 'Generated by `/agl-env-bundle` on %s. Contents:\n\n' "$(date +%Y-%m-%d)"
    printf '%s\n' "$entries" | sed 's/^/- `/;s/$/`/'
    cat <<'BODY'

## Restore (new machine)

Run at the repo root — paths inside the archive are relative:

```bash
7zz x secrets/env-bundle.zip     # prompts for the password
```

The password is **not in this repo**. Ask a teammate over a private channel.
No `7zz`? macOS: `brew install sevenzip` · Debian/Ubuntu: `apt install p7zip-full`.

## Repack (after any env file changes)

Nothing repacks automatically, and nothing notices a NEW env file. Use the
skill — it packs the full inventory and refuses to leave an unverified archive:

```
/agl-env-bundle repack
```

## Rules

- **This repo must stay PRIVATE.** If it ever goes public, treat every key in
  the bundle as leaked — git history keeps the archive forever.
- **Old archives in history stay decryptable with the old password.** To
  invalidate a secret, rotate it at the provider; changing the zip password
  does nothing.
- **Never `zip -e`.** macOS `zip` only does ZipCrypto, which breaks under a
  known-plaintext attack — and `.env` files start with guessable keys.
- **Filenames are not encrypted.** Anyone with the repo sees which env files
  exist and where; only their contents are protected.
BODY
  } > "$out"
  ok "wrote $out ($(printf '%s\n' "$entries" | wc -l | tr -d ' ') entries)"
}

# =============================================================================
case "${1:-}" in
  preflight) shift; cmd_preflight "$@" ;;
  inventory) shift; cmd_inventory "$@" ;;
  pack)      shift; cmd_pack "$@" ;;
  verify)    shift; cmd_verify "$@" ;;
  drift)     shift; cmd_drift "$@" ;;
  list)      shift; cmd_list "$@" ;;
  restore)   shift; cmd_restore "$@" ;;
  readme)    shift; cmd_readme "$@" ;;
  *) sed -n '2,18p' "$0"; exit 1 ;;
esac
