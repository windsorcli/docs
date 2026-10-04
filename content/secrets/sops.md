---
title: SOPS
description: Keep secrets in an encrypted file in the context, commit it, and reference its keys from the context's environment.
---

Windsor reads [SOPS](https://github.com/getsops/sops)-encoded secrets from a YAML file at `contexts/<context>/secrets.enc.yaml`.

Enable the provider in `contexts/<context>/values.yaml`. Without it, `sops` references fail with `no provider found for vault "sops"`:

```yaml
secrets:
  sops:
    enabled: true
```

## Create the file

Put your SOPS key rules in a `.sops.yaml` at the project root, then let SOPS create the file. It opens your editor and writes the encrypted result on save:

```bash
sops contexts/<context>/secrets.enc.yaml
```

The decrypted content is ordinary YAML. Nested keys flatten to dot-paths, so this file defines `database.password`:

```yaml
database:
  password: example-password
```

Reference it from `environment` in the same `values.yaml`:

```yaml
environment:
  DB_PASSWORD: ${secret("sops", "database.password")}
```

To change a value, run the same `sops` command and edit the file. Windsor decrypts the file again each time a Windsor command starts, so `windsor plan` and `windsor apply` use the new value right away. A shell that already exported the old value keeps it until you start a new shell. See [Caching](overview.md#caching).

## File names

Windsor loads `secrets.yaml`, `secrets.yml`, `secrets.enc.yaml`, and `secrets.enc.yml` from the context directory. It decides whether a file is encrypted by trying to decrypt it with `sops`.

- `secrets.enc.yaml` is meant to be committed.
- `secrets.yaml` is git-ignored, like `.env`. It must also be encrypted. Windsor refuses a plaintext one and reports `refusing to load unencrypted secrets file`.

To encrypt an existing plaintext file, run `sops -e -i contexts/<context>/secrets.yaml`. To commit the file, rename the encrypted file to `secrets.enc.yaml`. Renaming a plaintext file does not encrypt it, and git then tracks the plain text.

The [Contexts directory reference](https://www.windsorcli.dev/reference/cli/contexts) has the full file layout and error text.

## See also

- [Secrets overview](overview.md): reference syntax, caching, masking, troubleshooting
- [1Password](1password.md): the other supported provider
