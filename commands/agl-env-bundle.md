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

## 1. The password is this project's own — resolved, never invented

**Every project has its own password** (a group of projects may deliberately
share one through a common `auth-info/`). A workspace holding several projects
therefore holds several passwords, and that is correct. **Never suggest
"unifying" them** — that is a rotation of every bundle involved, and it is the
owner's security decision, not a tidy-up.

The script collects every candidate, most specific first, and prints which one
it used:

| | Source | Note |
|---|---|---|
| 1 | `$ENV_BUNDLE_PASS` | An explicit export. One-off, stored nowhere. |
| 2 | `PASS_ZIP=` in this repo's `.env.bak` | The repo's own copy. Often lives *inside* the archive, so a fresh clone does not have it yet. |
| 3 | walking **upwards** from the repo root, at each level: `auth-info/zip.<repo-folder>.env`, then `auth-info/zip.env` | `PASSWORD=` or `PASS_ZIP=`, outside every git repo. The first name is **this project's**; the second is a **group's**. The nearest `zip.env` may belong to a sibling project — that is why candidates are tested, not trusted. |

**When an archive exists, the candidate that actually OPENS it wins** —
`restore`, `verify` and `pack` all test with 7-Zip before using one. A candidate
that does not open it is listed in the report, never used.

When nothing opens the archive: `restore` writes **nothing** (on a terminal it
asks for the password and tests it first); `pack` **refuses** — packing would
silently change the password of a bundle other people rely on. Ask the owner for
**this project's** password and where they keep it. Do not borrow another
project's, do not invent one, do not take a default. Only when they confirm the
project has none yet, offer the menu in
[references/env-bundle.md](${CLAUDE_PLUGIN_ROOT}/references/env-bundle.md).

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
skipped; relay that list. An existing **empty** file whose archive copy is not
empty is replaced and reported: that is debris from a failed extraction, not a
local edit. Then confirm the app reads the env (run the project's own env
command if it has one) and go to §7.

If the password came from the repo's own `.env.bak` or was typed, the next fresh
clone will not find it. Offer to store it as `auth-info/zip.<repo-folder>.env`
above the repo — writing a secret to disk is the owner's call.

## 4. SETUP

1. `bash "$EB" inventory` — show the list and get the owner to **confirm** it.
   Stale or machine-local files should not go in.
2. Password per §1. With no archive yet there is nothing to test a candidate
   against, and the nearest `auth-info/zip.env` may be a sibling project's — so
   the script warns on every first pack, and you **confirm with the owner** that
   the source it names is this project's password. Store it as
   `auth-info/zip.<repo-folder>.env` (this project) or `auth-info/zip.env` (a
   group that deliberately shares one).
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
rotation, and `pack` refuses it unless asked for by name:

```bash
ENV_BUNDLE_ROTATE=1 ENV_BUNDLE_PASS='<new>' bash "$EB" pack   # owner's decision only
```

Say so plainly: every teammate has to be given the new one, and old archives in
history still open with the old password.

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
bundle now / repack including the files you left out / store this project's
password where a fresh clone finds it. Rotating a password is never the
recommendation, and "one password for the whole workspace" is never an option.
