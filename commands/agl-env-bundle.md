---
description: Restore, set up, or repack an AES-256 encrypted bundle of gitignored .env files committed into a PRIVATE repo — a fresh clone gets the whole configuration back
---

Read `${CLAUDE_PLUGIN_ROOT}/references/core-behaviors.md`.

`.env*` files are gitignored, but an **AES-256 encrypted** copy of them
(`secrets/env-bundle.zip`) is committed. A new machine clones and restores the
whole configuration instead of collecting files one by one.

Secrets are a **risk gate** (core-behaviors): pack and commit are the owner's
call, never yours. Everything runs through the bundled script, which refuses to
leave an unverified archive on disk:

```bash
EB="${CLAUDE_PLUGIN_ROOT}/scripts/env-bundle.sh"
```

## Mode

`$ARGUMENTS` may name one (`restore` / `setup` / `repack`). Otherwise detect,
and ask only if it stays ambiguous:

| Mode | Signal | Go to |
|---|---|---|
| **RESTORE** | archive exists, env files do not | §3 |
| **SETUP** | no archive yet | §4 |
| **REPACK** | archive exists, env files changed | §5 |

## 1. The password is resolved, never invented

`bash "$EB" pack` resolves it in this order and prints which one won:

| | Source | Note |
|---|---|---|
| 1 | `$ENV_BUNDLE_PASS` | An explicit export wins. One-off, stored nowhere. |
| 2 | `auth-info/zip.env`, searched **upwards** from the repo root | The normal case. `PASSWORD=` or `PASS_ZIP=`. Lives outside every git repo, so one password serves every bundle in the workspace. Rename it with `ENV_BUNDLE_SHARED_PASS_REL`. |
| 3 | `PASS_ZIP=` in this repo's `.env.bak` | Legacy fallback for a repo outside any workspace. |

**When it resolves one, USE IT and say where it came from — do not ask again.**
Two passwords for one workspace means half the bundles open with one string and
half with the other.

When it finds nothing, `pack` **refuses** and prints the three places it looked.
Do not invent a password and do not take a default: a bundle packed with a
password the team does not hold is a bundle nobody can restore, and it looks
fine until somebody tries. Ask the owner — first *where their password file is*
(it is usually one directory further up), and only if there is none, offer the
menu in [references/env-bundle.md](${CLAUDE_PLUGIN_ROOT}/references/env-bundle.md).

`restore` is the one command allowed to proceed without a stored password — a
human is at the keyboard and 7-Zip prompts. `pack` is not: there the password
*becomes* the archive.

## 2. Preflight — every mode, no exceptions

```bash
bash "$EB" preflight
```

Five gates, non-zero on any failure: repo is **PRIVATE** (on a public repo every
key inside is already burned and history keeps it forever); 7-Zip present; git
actually ignores env files (probed with `check-ignore`, not grepped); no raw env
file already **tracked** (if one is, it is in history — the fix is rotating that
secret at the provider); and the archive path is **not** gitignored (a repo that
ignores `secrets/` makes `git add` a silent no-op that still exits 0).

**Never `zip -e`** — macOS `zip` only offers ZipCrypto, which falls to a
known-plaintext attack with ~12 known bytes, and `.env` files open with
guessable keys like `FIREBASE_API_KEY=`. A ZipCrypto bundle in git is plaintext.

## 3. RESTORE

```bash
bash "$EB" restore            # existing files are SKIPPED, local edits kept
bash "$EB" restore --force    # only when the owner asks for the archive's copy
```

Env files are gitignored, so an overwrite is **not** recoverable with git —
that is why skip-existing is the default. The script names every file it
skipped; relay that list. Then confirm the app reads the env (run the project's
own env command if it has one) and go to §7.

## 4. SETUP

1. `bash "$EB" inventory` — show the list and get the owner to **confirm** it.
   Stale or machine-local files should not go in.
2. Password per §1. Store it where §1 will find it next time.
3. Pack — §5.
4. `bash "$EB" readme` — writes `secrets/README.md` from the archive's **real**
   contents, so the doc cannot drift from the file list.
5. Stop for sign-off, then commit exactly two files:
   ```bash
   git add secrets/README.md secrets/env-bundle.zip
   git ls-files secrets/     # only README.md + env-bundle.zip
   git status --short        # no .env* staged
   ```

## 5. PACK / REPACK

```bash
bash "$EB" pack               # no file list = the WHOLE inventory
```

Packing the full inventory is the default because the failure this pattern
actually produces is a **new env file missing from a hand-typed list** — the
pack succeeds, verify says VERIFIED, and the next clone is quietly short a
secret. `pack` verifies (§6), **deletes the archive if verification fails**, and
then compares the archive against the inventory. An undeclared gap is a hard
failure; a deliberate omission must be declared, and is still reported:

```bash
ENV_BUNDLE_EXCLUDE=".env.local" bash "$EB" pack
```

A **different** password than the current bundle's is not a repack — it is a
rotation. Say so plainly: every teammate has to be given the new one, and old
archives in history still open with the old password.

Re-run `bash "$EB" readme` if the file list changed, then §7.

## 6. Verify — automatic after every pack, standalone to audit

```bash
bash "$EB" verify   # AES-256 method + right password opens + wrong password rejected
bash "$EB" drift    # archive contents vs what is on disk
```

All three verify checks must pass. `ZipCrypto` or `Store` means the bundle is
not encrypted; a wrong password that *opens* it means the same thing.

## 7. Report, then the menu

Report: mode, archive path + entry count + "AES-256 verified", the file list,
**where the password came from** (never the password itself), drift status, and
the commit hash or "not committed — waiting on you".

Then a numbered menu with exactly one recommendation — typically: commit the
bundle now / repack including the files you left out / rotate the password.
