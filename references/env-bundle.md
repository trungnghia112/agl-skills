# env-bundle — password policy and threat model

Read when `/agl-env-bundle` has to **choose** a password (the script found none)
or when the owner asks what this pattern actually protects.

## Choosing a password

The archive password is the only thing between a committed archive and every
secret in the repo. **Never choose it for the owner, and never default.**

**Passwords are per project.** A workspace holds many projects and, normally,
many passwords — one per project, or one per group of projects that share an
`auth-info/` directory on purpose. That is the design, not drift to clean up:
one leaked string should open one project, not all of them.

First: is there already one? `scripts/env-bundle.sh` collects `$ENV_BUNDLE_PASS`,
`PASS_ZIP=` in `.env.bak`, then — walking **upwards** from the repo root —
`auth-info/zip.<repo-folder>.env` and `auth-info/zip.env` at each level. When an
archive exists, the one that **opens it** is used and named; the nearest
`zip.env` is frequently a sibling project's and is skipped when it does not open.

When nothing is found (or nothing opens the archive) it refuses and lists what
it tried. The first question is then **not** the menu below — it is *what this
project's password is and where they keep it*, because most of the time it
exists: in a password manager, in the repo's old `.env.bak`, or under another
name.

Only once they confirm this project has none yet, ask with a closed menu (never
open-ended):

> 1. **Generate a 24-byte random password** (`openssl rand -base64 24`) —
>    strongest; must go straight into a password manager, nobody memorises it
> 2. **You type one** — used exactly as given, not "improved"
> 3. **Use the group's password** — only when this project belongs to a group
>    that already shares one through its `auth-info/zip.env`
>
> I suggest option 1 — it is the only one whose strength does not depend on a
> human having chosen well.

There is deliberately no "skip / use a default" option. A documented default
password is a published one: every repo that takes it opens in seconds to anyone
who gets the archive, and demo repos become real repos without anyone repacking.

## Storing it

Write it where the next run finds it, outside every git repository:

```
PASSWORD=the-password        # <any-dir-above-the-repo>/auth-info/zip.<repo-folder>.env   (this project)
PASSWORD=the-password        # <group-dir>/auth-info/zip.env                               (a group that shares one)
```

Prefer the per-project name. A `zip.env` is read by every repo underneath it,
so placing one at the workspace root makes it the first guess for projects it
does not belong to — harmless now that candidates are tested, but it is how a
workspace ends up looking like it "should" have one password. Then hand it to
the owner for their password manager and for the team over a private channel —
not in the repo, not in an issue, not in a commit message.

The cost of this design is stated rather than hidden: **a clone alone is not
enough** — the machine also needs the `auth-info/` file (or a person who types
the password once). The older habit of keeping `PASS_ZIP=` in a `.env.bak` that
is packed *inside* the archive does not help a fresh clone at all — the file is
not readable until the archive is already open — and anyone who opens the
archive once learns the password permanently. Prefer an `auth-info/` file.

## Special characters

The password reaches 7-Zip as `-p"$PASS"`, always through a variable. Never
paste a literal into a command line: `$`, `!`, and backticks get eaten by the
shell and the archive silently ends up with a **different** password than the
owner believes. Files edited on Windows carry a trailing `\r`, which 7-Zip takes
as part of the password — the script strips it. `verify` check 2 is what catches
both of these.

## Rotation

Changing the password is **not** a repack, and `pack` refuses to do it as a side
effect: when no password it finds opens the current archive, it stops instead
of re-encrypting with whatever it found (which, before this guard, could be a
sibling project's password — and `verify` then reported VERIFIED). A deliberate
rotation is spelled out: `ENV_BUNDLE_ROTATE=1 ENV_BUNDLE_PASS=<new>`. Every
teammate must be given the new one, and old archives in git history still open
with the old one. To invalidate a leaked secret, rotate it at the provider
(Firebase, Stripe, the API vendor) — changing the zip password does nothing.

## Why not `zip -e`

The `zip` shipped with macOS only implements **ZipCrypto**, which falls to a
known-plaintext attack given roughly 12 known bytes of a file. `.env` files begin
with highly guessable keys — `FIREBASE_API_KEY=`, `NODE_ENV=`, `DATABASE_URL=` —
so that requirement is met for free. A ZipCrypto archive committed to git is, in
practice, plaintext.

Always `7zz -tzip -mem=AES256`. `-mem=AES256` is mandatory: the `-tzip` default
*is* ZipCrypto, so omitting it silently produces a broken archive that still asks
for a password. `verify` check 1 exists solely to catch this.

## What this protects, and what it does not

**Protects:** the archive's contents against anyone who has the repo but not the
password — a leaked clone, a stolen laptop backup, a contractor with read access.

**Does not protect against:**

- **A public repo.** Every key inside must be treated as leaked, and history
  keeps the archive forever. Preflight hard-fails for this reason.
- **Anyone who has ever had the password.** There is no revocation; removing
  someone means rotating every secret at its provider.
- **History.** Old archives stay decryptable with the old password for as long
  as the repo exists.
- **Filenames.** ZIP does not encrypt the central directory. Anyone with the
  repo can list the entries and learn which env files exist and where — only
  their contents are protected.
- **Drift.** Nothing outside `pack`'s own check notices that an env file changed.
  A bundle is only as current as the last deliberate repack.
- **Process visibility.** 7-Zip takes the password via `-p`, so it is briefly
  visible in `ps` to other users on a shared machine.

## When to outgrow this

The pattern trades rigour for zero infrastructure. When that stops being the
right trade — a team past a handful of people, a contractor who must lose access
without everyone rotating, an audit trail requirement:

- **SOPS + age/KMS** — per-key encryption, readable diffs, access revocable per
  person without repacking.
- **git-crypt** — transparent encrypt/decrypt on checkout, per-user GPG keys.
- **GCP Secret Manager / AWS Secrets Manager / Doppler / Vault** — secrets leave
  the repo entirely; rotation and audit logging come built in.
