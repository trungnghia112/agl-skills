# env-bundle — password policy and threat model

Read when `/agl-env-bundle` has to **choose** a password (the script found none)
or when the owner asks what this pattern actually protects.

## Choosing a password

The archive password is the only thing between a committed archive and every
secret in the repo. **Never choose it for the owner, and never default.**

First: is there already one? `scripts/env-bundle.sh` searches `$ENV_BUNDLE_PASS`,
then `auth-info/zip.env` **upwards** from the repo root, then `PASS_ZIP=` in
`.env.bak`. When it resolves one, use it and say which file it came from. Asking
again invites a second password for a workspace that has one, and then half the
bundles open with one string and half with another.

When it finds nothing it refuses to pack and says so. The first question is then
**not** the menu below — it is *where their password file is*, because most of
the time it exists and sits one directory further up, or under another name.

Only once they confirm there is none, ask with a closed menu (never open-ended):

> 1. **Generate a 24-byte random password** (`openssl rand -base64 24`) —
>    strongest; must go straight into a password manager, nobody memorises it
> 2. **You type one** — used exactly as given, not "improved"
> 3. **Reuse the password you already use for another bundle in this workspace**
>    — one string opens every repo; store it once in `auth-info/zip.env`
>
> I suggest option 1 — it is the only one whose strength does not depend on a
> human having chosen well.

There is deliberately no "skip / use a default" option. A documented default
password is a published one: every repo that takes it opens in seconds to anyone
who gets the archive, and demo repos become real repos without anyone repacking.

## Storing it

Write it to the shared store, so every repo in the workspace uses one password
and the next run does not ask:

```
PASSWORD=the-password        # <workspace>/auth-info/zip.env
```

`auth-info/` sits outside every git repository, which is why it can live there
in the clear. Then hand it to the owner for their password manager and for the
team over a private channel — not in the repo, not in an issue, not in a commit
message.

The cost of this design is stated rather than hidden: **a clone alone is not
enough** — the machine also needs `auth-info/`. The older trade-off, packing
`.env.bak` (with `PASS_ZIP=`) *inside* the archive to make a lone clone
self-sufficient, means anyone who opens the archive once knows the password
permanently. Prefer the shared store.

## Special characters

The password reaches 7-Zip as `-p"$PASS"`, always through a variable. Never
paste a literal into a command line: `$`, `!`, and backticks get eaten by the
shell and the archive silently ends up with a **different** password than the
owner believes. Files edited on Windows carry a trailing `\r`, which 7-Zip takes
as part of the password — the script strips it. `verify` check 2 is what catches
both of these.

## Rotation

Changing the password is **not** a repack. Every teammate must be given the new
one, and old archives in git history still open with the old one. To invalidate
a leaked secret, rotate it at the provider (Firebase, Stripe, the API vendor) —
changing the zip password does nothing.

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
