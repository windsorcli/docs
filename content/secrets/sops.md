---
title: SOPS
description: Keep a context's secrets in a SOPS-encrypted file that you commit, and reference its keys from values.yaml, blueprint inputs, and .env files.
---

<!-- ai: rough draft. Structure only; the docs owner writes the final prose from the dossier. -->

[SOPS](https://github.com/getsops/sops) encrypts the values in a YAML file and leaves the keys readable, so an encrypted secrets file can live in git and go through review like any other file. Windsor decrypts a context's SOPS files when a command needs a value, and serves their keys to `secret("sops", ...)` references. This page assumes you have a SOPS key, such as an age key or a cloud KMS key. The [SOPS documentation](https://getsops.io/docs/) covers making one.

## Enable the provider

Turn the provider on in the context's `values.yaml`:

```yaml
# contexts/local/values.yaml
secrets:
  sops:
    enabled: true
```

Without this, every `sops` reference fails with `No secrets provider handles the vault "sops".` With it, Windsor requires `sops` 3.10.0 or later on your `PATH`.

## Create the file

SOPS picks the key for a file from a `.sops.yaml` at the project root. This rule encrypts every context's secrets files for one age recipient:

```yaml
# .sops.yaml
creation_rules:
  - path_regex: contexts/.*/secrets(\.enc)?\.ya?ml$
    age: age1ufz7ckwlg4qkcmqp59c2cclkajhv0tgawm6sqcw39vr2g0mdffws6j9frc
```

Then open the file with `sops`. It starts your editor, and on save it writes the encrypted result:

```bash
sops contexts/local/secrets.enc.yaml
```

The decrypted content is ordinary YAML. Nested keys flatten to dot-paths, so this file defines `database.password`:

```yaml
database:
  password: example-password
```

On disk, SOPS keeps the keys and encrypts each value:

```yaml
database:
    password: ENC[AES256_GCM,data:6QXqXk8wrnjSZf0Sp/qANQ==,iv:...,type:str]
sops:
    age:
```

## Reference a key

Reference the key by its dot-path, with `sops` as the vault:

```yaml
# contexts/local/values.yaml
environment:
  DB_PASSWORD: ${secret("sops", "database.password")}
```

The same reference works in a Terraform input, a `.env` file, or a Kubernetes Secret. See [Where to use a secret](overview.md#where-to-use-a-secret).

A key that no file defines leaves an error marker in the variable:

```text
The SOPS secrets files have no value at database.api_key.
```

## Change a value

Run the same `sops` command and edit the file. Windsor decrypts the files again at the start of each command, so `windsor plan`, `windsor apply`, and `windsor exec` use the new value at once. A shell that already holds the old value keeps it until you open a new shell or set `NO_CACHE=1`. See [Caching](overview.md#caching).

## File names

Windsor loads up to four files from the context directory, in this order:

1. `secrets.yaml`
2. `secrets.yml`
3. `secrets.enc.yaml`
4. `secrets.enc.yml`

When two files define the same key, the later file wins. Keys that only one file defines are all available.

`contexts/<context>/.gitignore` ignores `secrets.yaml` and `secrets.yml`, and not the `.enc` names. Commit `secrets.enc.yaml`. Keep `secrets.yaml` for values that stay on your machine.

Windsor decides whether a file is encrypted by trying to decrypt it, so `secrets.yaml` must be encrypted too. Windsor refuses a plaintext one, and the command stops:

```text
error: Windsor does not load the unencrypted secrets file /path/to/project/contexts/local/secrets.yaml.
hint: Encrypt the file with sops and save it as secrets.enc.yaml.
```

To encrypt a plaintext file in place, run `sops -e -i contexts/local/secrets.yaml`. Renaming a plaintext file to `secrets.enc.yaml` does not encrypt it, and git then tracks the plain text.

## Troubleshooting

When SOPS can't decrypt an `.enc` file with the keys it has, the command stops:

```text
error: Windsor cannot decrypt the secrets file /path/to/project/contexts/local/secrets.enc.yml: sops decryption failed: Failed to get the data key required to decrypt the SOPS file.
hint: Make sure that your sops key can decrypt the file. Run 'sops --decrypt /path/to/project/contexts/local/secrets.enc.yml' to see the full error.
```

Run the `sops --decrypt` command from the hint. It names the key that SOPS looked for. The most common cause is a file encrypted for a teammate's key and not yours: add your recipient to `.sops.yaml`, and have someone who can decrypt the file run `sops updatekeys` on it.

<!-- ai: `sops updatekeys` is SOPS behavior, not validated in this run. Keep or cut? -->

The [contexts reference](https://www.windsorcli.dev/reference/cli/contexts#secrets-files) has the file layout.

## See also

- [Secrets overview](overview.md): reference syntax, where references go, caching, masking
- [1Password](1password.md): the other provider
