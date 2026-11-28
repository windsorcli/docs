---
title: SOPS
description: Keep a context's secrets in a SOPS-encrypted file that you commit, and reference its keys from values.yaml, blueprint inputs, and .env files.
---

- SOPS encrypts values in a YAML file, keys stay readable (live, Commands: The encrypted file)
- so the file can live in git and go through review (follows from the above)
- Windsor decrypts a context's SOPS files when a command needs a value (live, claim 13)
- serves keys to `secret("sops", ...)` (live, overview claim 2)
- assumes a SOPS key exists: age, PGP, or cloud KMS; link `https://getsops.io/docs/` (no claim; scope)

## Enable the provider

- `secrets.sops.enabled: true` in the context's `values.yaml` (live, claim 1)
- default `false` (source, Defaults)
- off: every `sops` reference fails with `No secrets provider handles the vault "sops".` (live, claim 1)
- on: `sops` 3.10.0 or later required on `PATH` for `init`, `plan`, `apply`, `install`, `destroy`, `down` (source, claim 2)
- missing: `SOPS >= 3.10.0 is required but was not found on PATH.`, hint `Install SOPS from https://github.com/getsops/sops/releases.` (source, claim 2)

## Create the file

- SOPS picks the key from `.sops.yaml` at the project root (live, Commands: `.sops.yaml` used by the run)
- a creation rule matching `contexts/.*/secrets(\.enc)?\.ya?ml$` covers every context (live)
- `sops contexts/<context>/secrets.enc.yaml` opens the editor, writes the encrypted file on save (source, claim 12; SOPS behavior, the run used `sops -e -i`)
- decrypted content is ordinary YAML (live, claim 10)
- nested keys flatten to dot-paths: `database: {password: x}` defines `database.password` (live, claim 10)
- on disk: keys readable, each value `ENC[AES256_GCM,...]`, plus a `sops:` metadata block (live)
- every value is read as a string; numbers and booleans print in Go `%v` form (source, Limits)

## Reference a key

- vault `sops`, item the dot-path: `${secret("sops", "database.password")}` (live, overview claim 2)
- same reference works in inputs, `.env`, Kubernetes Secrets: link `overview.md#where-to-use-a-secret`
- a third argument is joined with a dot (live, claim 15; optional)
- a key no file defines: marker `The SOPS secrets files have no value at <path>.` (live, claim 11)

## Change a value

- run the same `sops` command, edit (SOPS behavior)
- Windsor decrypts the files again at the start of each command (live, claim 13)
- `plan`, `apply`, `exec` see the change at once (live, claim 13)
- an open shell keeps the old value until a new shell or `NO_CACHE=1`; link `overview.md#caching` (live, overview claim 20)

## File names

- four names in `contexts/<context>/`, in merge order: `secrets.yaml`, `secrets.yml`, `secrets.enc.yaml`, `secrets.enc.yml` (live, claim 3)
- a key in two files: the later file wins (live, claim 4)
- keys only one file defines all resolve (live, claim 4: `ONLY_YAML`)
- one set of files per context; no setting for another path (source, Limits)
- `contexts/<context>/.gitignore` ignores `secrets.yaml` and `secrets.yml`, not the `.enc` names (live, claim 9)
- commit `secrets.enc.yaml`; `secrets.yaml` for values that stay local (follows from claim 9)
- encryption is decided by trying to decrypt, not by the name (live, claim 5)
- so `secrets.yaml` must be encrypted too; a plaintext one is refused and stops the command (live, claims 6–7)
- the hook prints nothing for it; `env --decrypt` and `plan` print and exit 1 (live, claim 7)
- `sops -e -i contexts/<context>/secrets.yaml` encrypts in place (live, claim 14)
- renaming a plaintext file to `secrets.enc.yaml` does not encrypt it; git then tracks the plain text (follows from claims 5, 9)

## Troubleshooting

- an `.enc` file the keys cannot decrypt stops the command with `error:` and `hint:` (live, claim 8)
- the hint's `sops --decrypt <path>` shows the full SOPS error (live, claim 8)
- common cause: a file encrypted for a teammate's key (live: the run encrypted for a second age key)
- fix: add the recipient to `.sops.yaml`, then someone who can decrypt runs `sops updatekeys` (SOPS behavior; not run)
- the error table under Defaults, limits, and errors lists every message
- link for the file layout: `https://www.windsorcli.dev/reference/cli/contexts#secrets-files`

## See also

- `overview.md`: reference syntax, where references go, caching, masking
- `1password.md`: the other provider
