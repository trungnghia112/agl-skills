#!/usr/bin/env bash
# test-env-bundle.sh — regression suite for scripts/env-bundle.sh.
#
#   bash scripts/test-env-bundle.sh
#
# One case per defect that was real in the version this command was ported from,
# so a later edit cannot quietly reintroduce it. Builds throwaway git repos in a
# temp dir; touches nothing in this repo.
#
# NOT wired into scripts/validate.sh: this needs 7-Zip, and CI has none. validate
# gates the manifest/wiring; this gates the behaviour. Run it after any edit to
# scripts/env-bundle.sh.
# Regression suite for scripts/env-bundle.sh — one case per confirmed defect.
set -uo pipefail
EB="$(cd "$(dirname "$0")/.." && pwd)/scripts/env-bundle.sh"
ROOT="$(mktemp -d)/env-bundle-tests"; rm -rf "$ROOT"; mkdir -p "$ROOT"
command -v 7zz >/dev/null 2>&1 || command -v 7z >/dev/null 2>&1 \
  || { echo "SKIP: 7-Zip not installed (brew install sevenzip)"; exit 0; }

pass=0; failn=0
t()  { printf '\n── %s\n' "$1"; }
yes_() { if eval "$2"; then printf '   ✓ %s\n' "$1"; pass=$((pass+1)); else printf '   ✗ %s\n' "$1"; failn=$((failn+1)); fi; }

newrepo() {  # newrepo <name> <gitignore-content>
  local d="$ROOT/$1"; mkdir -p "$d"; cd "$d"; git init -q .
  printf '%s' "$2" > .gitignore
  printf 'API_KEY=abc\n' > .env
  printf 'X=1\n' > .env.local
  printf 'API_KEY=\n' > .env.example
  git add -A && git -c user.email=t@t -c user.name=t commit -qm init
}

t "1. preflight accepts '.env*' (broader than '.env' + '.env.*')"
newrepo r1 '.env*
!.env.example
'
out="$(ENV_BUNDLE_PASS=pw bash "$EB" preflight 2>&1)"; rc=$?
yes_ "preflight exits 0"                       "[ $rc -eq 0 ]"
yes_ "gitignore probed behaviorally"           'grep -q "git ignores env files" <<<"$out"'

t "2. preflight rejects a gitignored archive path"
printf 'secrets/\n' >> .gitignore
out="$(ENV_BUNDLE_PASS=pw bash "$EB" preflight 2>&1)"; rc=$?
yes_ "preflight exits non-zero"                "[ $rc -ne 0 ]"
yes_ "says git add would do nothing"           'grep -q "silently do nothing" <<<"$out"'
sed -i "" '/^secrets\/$/d' .gitignore

t "3. pack with no args packs the FULL inventory (no silent drift)"
mkdir -p functions && printf 'STRIPE=sk_live\n' > functions/.env
out="$(ENV_BUNDLE_PASS='p@ss!w' bash "$EB" pack 2>&1)"; rc=$?
yes_ "pack exits 0"                            "[ $rc -eq 0 ]"
yes_ "functions/.env is in the archive"        'ENV_BUNDLE_PASS="p@ss!w" bash "$EB" list | grep -qx "functions/.env"'
yes_ "reports no drift"                        'grep -q "no drift" <<<"$out"'

t "4. an explicit, STALE file list is reported as drift"
printf 'NEW=1\n' > .env.staging
out="$(ENV_BUNDLE_PASS='p@ss!w' bash "$EB" pack .env .env.local functions/.env 2>&1)"; rc=$?
yes_ "an UNDECLARED gap fails the pack"        "[ $rc -ne 0 ]"
yes_ "DRIFT names the missing file"            'grep -q "DRIFT" <<<"$out" && grep -q ".env.staging" <<<"$out"'
yes_ "archive is kept (it is valid, just short)" '[ -f secrets/env-bundle.zip ]'
yes_ "standalone drift exits non-zero"         '! ENV_BUNDLE_PASS="p@ss!w" bash "$EB" drift >/dev/null 2>&1'

t "4b. a DECLARED exclusion is forgiven, and still reported"
out="$(ENV_BUNDLE_EXCLUDE='.env.staging' ENV_BUNDLE_PASS='p@ss!w' bash "$EB" pack .env .env.local functions/.env 2>&1)"; rc=$?
yes_ "pack exits 0"                            "[ $rc -eq 0 ]"
yes_ "the exclusion stays visible"             'grep -q "deliberately excluded" <<<"$out"'
yes_ "an UNDECLARED file still fails"          '! ENV_BUNDLE_EXCLUDE=".env.staging" ENV_BUNDLE_PASS="p@ss!w" bash "$EB" pack .env functions/.env >/dev/null 2>&1'

t "5. restore does NOT clobber local edits by default"
ENV_BUNDLE_PASS='p@ss!w' bash "$EB" pack >/dev/null 2>&1
printf 'API_KEY=I_EDITED_THIS\n' > .env
out="$(ENV_BUNDLE_PASS='p@ss!w' bash "$EB" restore 2>&1)"
yes_ "local edit survives"                     'grep -q I_EDITED_THIS .env'
yes_ "the skip is reported"                    'grep -q "SKIPPED" <<<"$out"'
yes_ "a deleted file IS restored"              'rm -f .env.local; ENV_BUNDLE_PASS="p@ss!w" bash "$EB" restore >/dev/null 2>&1; [ -f .env.local ]'
ENV_BUNDLE_PASS='p@ss!w' bash "$EB" restore --force >/dev/null 2>&1
yes_ "--force does overwrite"                  '! grep -q I_EDITED_THIS .env'

t "6. zip-slip: a path escaping the repo root is refused, both ways"
mkdir -p "$ROOT/outside" && printf 'OUT=1\n' > "$ROOT/outside/.env"
out="$(ENV_BUNDLE_PASS='p@ss!w' bash "$EB" pack .env ../outside/.env 2>&1)"; rc=$?
yes_ "pack refuses ../"                        "[ $rc -ne 0 ]"
yes_ "and says why"                            'grep -q "escapes the repo root" <<<"$out"'
# an archive packed by the OLD script still carries ../ — restore must refuse it
rm -f secrets/env-bundle.zip
7zz a -tzip -mem=AES256 -p'p@ss!w' -spf secrets/env-bundle.zip .env ../outside/.env >/dev/null 2>&1
out="$(ENV_BUNDLE_PASS='p@ss!w' bash "$EB" restore 2>&1)"; rc=$?
yes_ "restore refuses a legacy ../ archive"    "[ $rc -ne 0 ]"
yes_ "outside file untouched"                  'grep -q "OUT=1" "$ROOT/outside/.env"'

t "7. verify catches an unencrypted / ZipCrypto archive"
rm -f secrets/env-bundle.zip; 7zz a -tzip secrets/env-bundle.zip .env >/dev/null
out="$(ENV_BUNDLE_PASS='p@ss!w' bash "$EB" verify 2>&1)"; rc=$?
yes_ "verify exits non-zero"                   "[ $rc -ne 0 ]"
yes_ "flags the method"                        'grep -q "NOT AES-256" <<<"$out"'
yes_ "flags the wrong password opening it"     'grep -q "WRONG password opened" <<<"$out"'

t "8. pack refuses to run with no password (never invents one)"
rm -f secrets/env-bundle.zip
out="$(env -u ENV_BUNDLE_PASS ENV_BUNDLE_SHARED_PASS_REL=nope/none.env ENV_BUNDLE_PASS_FILE=nope.env bash "$EB" pack 2>&1)"; rc=$?
yes_ "exits non-zero"                          "[ $rc -ne 0 ]"
yes_ "no archive left behind"                  '[ ! -f secrets/env-bundle.zip ]'
yes_ "tells the agent to ASK the owner"        'grep -q "ASK THE OWNER" <<<"$out"'

t "9. shared password store, searched UPWARDS from a nested repo"
mkdir -p "$ROOT/ws/auth-info"; printf 'PASSWORD=shared-pw\n' > "$ROOT/ws/auth-info/zip.env"
mkdir -p "$ROOT/ws/a/b"; cd "$ROOT/ws/a/b"; git init -q .
printf '.env*\n!.env.example\n' > .gitignore; printf 'K=1\n' > .env
git add -A && git -c user.email=t@t -c user.name=t commit -qm init
out="$(env -u ENV_BUNDLE_PASS bash "$EB" pack 2>&1)"; rc=$?
yes_ "packs using the shared store 3 levels up" "[ $rc -eq 0 ]"
yes_ "report names the file it came from"       'grep -q "ws/auth-info/zip.env" <<<"$out"'
yes_ "and the shared password really opens it"  '7zz t -pshared-pw secrets/env-bundle.zip >/dev/null 2>&1'

t "10. a CRLF password file still yields the password the owner typed"
printf 'PASSWORD=crlf-pw\r\n' > "$ROOT/ws/auth-info/zip.env"
rm -f secrets/env-bundle.zip   # a first pack: repacking with a new password is a rotation (15)
env -u ENV_BUNDLE_PASS bash "$EB" pack >/dev/null 2>&1
yes_ "opens with 'crlf-pw', not 'crlf-pw\\r'"   '7zz t -pcrlf-pw secrets/env-bundle.zip >/dev/null 2>&1'

t "11. readme is generated from the archive's REAL contents"
printf 'PASSWORD=shared-pw\n' > "$ROOT/ws/auth-info/zip.env"
printf 'Z=1\n' > .env.worker
rm -f secrets/env-bundle.zip
env -u ENV_BUNDLE_PASS bash "$EB" pack >/dev/null 2>&1
env -u ENV_BUNDLE_PASS bash "$EB" readme >/dev/null 2>&1
yes_ "secrets/README.md lists .env.worker"     'grep -q ".env.worker" secrets/README.md'
yes_ "warns the repo must stay PRIVATE"        'grep -q "must stay PRIVATE" secrets/README.md'

t "12. inventory warns about an env file that is NOT gitignored"
printf 'LOOSE=1\n' > loose.env.prod 2>/dev/null
mkdir -p sub && printf 'L=1\n' > sub/.env.notignored
printf '.env\n!.env.example\n' > .gitignore   # narrower: sub/.env.notignored is no longer ignored
out="$(bash "$EB" inventory 2>&1 >/dev/null)"
yes_ "stderr names the unignored file"         'grep -q "NOT gitignored" <<<"$out"'

# Passwords are PER PROJECT (or per group of projects sharing one auth-info/).
# The nearest auth-info/zip.env above a repo can belong to a DIFFERENT project.
# Layout for 13-18: $ROOT/ws2/auth-info/zip.env holds another project's password;
# $ROOT/ws2/grp/proj is a repo whose own password is in .env.bak.
mkproj() {
  rm -rf "$ROOT/ws2"; mkdir -p "$ROOT/ws2/auth-info" "$ROOT/ws2/grp/proj"
  printf 'PASSWORD=other-project-pw\n' > "$ROOT/ws2/auth-info/zip.env"
  cd "$ROOT/ws2/grp/proj"; git init -q .
  printf '.env*\n!.env.example\n' > .gitignore; printf 'K=secret\n' > .env
  printf 'PASS_ZIP=this-project-pw\n' > .env.bak
  git add -A && git -c user.email=t@t -c user.name=t commit -qm init
  mkdir -p secrets
  7zz a -tzip -mem=AES256 -p'this-project-pw' -spf secrets/env-bundle.zip .env .env.bak >/dev/null
}
opens() { 7zz t -p"$1" secrets/env-bundle.zip >/dev/null 2>&1; }

t "13. repack keeps the password that OPENS the archive — never another project's"
mkproj
out="$(env -u ENV_BUNDLE_PASS bash "$EB" pack 2>&1)"; rc=$?
yes_ "pack exits 0"                            "[ $rc -eq 0 ]"
yes_ "still opens with this project's password" 'opens this-project-pw'
yes_ "does NOT open with the other project's"  '! opens other-project-pw'
yes_ "report names .env.bak as the source"     'grep -q "password from .env.bak" <<<"$out"'

t "14. repack refuses when no password found opens the archive (no silent rotation)"
mkproj; rm -f .env.bak; before="$(shasum secrets/env-bundle.zip)"
out="$(env -u ENV_BUNDLE_PASS bash "$EB" pack 2>&1)"; rc=$?
yes_ "pack exits non-zero"                     "[ $rc -ne 0 ]"
yes_ "archive left byte-identical"             '[ "$(shasum secrets/env-bundle.zip)" = "$before" ]'
yes_ "says it would be a rotation"             'grep -qi "rotation" <<<"$out"'
out="$(ENV_BUNDLE_PASS=typo bash "$EB" pack 2>&1)"; rc=$?
yes_ "an explicit WRONG password is refused too" "[ $rc -ne 0 ] && opens this-project-pw"

t "15. a deliberate rotation is allowed, and said out loud"
out="$(ENV_BUNDLE_ROTATE=1 ENV_BUNDLE_PASS=new-pw bash "$EB" pack 2>&1)"; rc=$?
yes_ "pack exits 0"                            "[ $rc -eq 0 ]"
yes_ "opens with the new password only"        'opens new-pw && ! opens this-project-pw'
yes_ "the report says ROTATION"                'grep -q "ROTATION" <<<"$out"'

t "16. restore tries every password found and uses the one that opens"
mkproj; mv .env.bak /tmp/eb-bak.$$; rm -f .env
mkdir -p "$ROOT/ws2/grp/auth-info"; printf 'PASSWORD=this-project-pw\n' > "$ROOT/ws2/grp/auth-info/zip.proj.env"
printf 'PASSWORD=other-project-pw\n' > "$ROOT/ws2/grp/auth-info/zip.env"
out="$(env -u ENV_BUNDLE_PASS bash "$EB" restore 2>&1)"; rc=$?
yes_ "restore exits 0"                         "[ $rc -eq 0 ]"
yes_ ".env restored with its content"          'grep -q "K=secret" .env'
yes_ "report names the file that opened it"    'grep -q "grp/auth-info/zip.proj.env" <<<"$out"'
rm -f /tmp/eb-bak.$$; rm -rf "$ROOT/ws2/grp/auth-info"

t "17. a restore with no working password writes NOTHING (no empty files)"
mkproj; rm -f .env .env.bak
out="$(env -u ENV_BUNDLE_PASS bash "$EB" restore </dev/null 2>&1)"; rc=$?
yes_ "restore exits non-zero"                  "[ $rc -ne 0 ]"
yes_ "no .env left behind, not even empty"     '[ ! -e .env ] && [ ! -e .env.bak ]'
yes_ "lists the passwords it tried"            'grep -q "auth-info/zip.env" <<<"$out"'

t "18. empty files left by an OLD failed restore are replaced, and reported"
: > .env; : > .env.bak
out="$(ENV_BUNDLE_PASS=this-project-pw bash "$EB" restore 2>&1)"; rc=$?
yes_ "restore exits 0"                         "[ $rc -eq 0 ]"
yes_ ".env now has its content"                'grep -q "K=secret" .env'
yes_ "the replacement is reported"             'grep -qi "empty" <<<"$out"'

t "19. setup (no archive yet) prefers this project's own file over the group's"
mkproj; rm -f secrets/env-bundle.zip .env.bak
printf 'PASSWORD=this-project-pw\n' > "$ROOT/ws2/auth-info/zip.proj.env"
out="$(env -u ENV_BUNDLE_PASS bash "$EB" pack 2>&1)"; rc=$?
yes_ "pack exits 0"                            "[ $rc -eq 0 ]"
yes_ "packed with zip.proj.env, not zip.env"   'opens this-project-pw && ! opens other-project-pw'
yes_ "asks to confirm it is THIS project's"    'grep -q "THIS project" <<<"$out"'

printf '\n════════════════════════════\n  %d passed, %d failed\n════════════════════════════\n' "$pass" "$failn"
exit "$failn"
