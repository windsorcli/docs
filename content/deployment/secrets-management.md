---
title: Secrets management
description: SOPS and 1Password integration.
---

Windsor manages secrets with [SOPS](https://github.com/getsops/sops) and the [1Password CLI](https://developer.1password.com/cli/).

## Overview

You can use multiple providers. After configuring a provider, reference secrets in your context's `environment` in `windsor.yaml`:

```yaml
version: v1alpha1
contexts:
  local:
    environment:
      CRITERION_PASSWORD: ${{ op.personal["The Criterion Channel"]["password"] }}
```

Here `op` is the 1Password provider and `personal` is the vault name.

## SOPS

Use [SOPS](https://github.com/getsops/sops) to encrypt secrets to a file and commit them safely. Configure SOPS and an `sops.yaml` in your project, then start plaintext locally:

```bash
$EDITOR contexts/<context>/secrets.yaml
```

Nested keys flatten to dot-path lookups, so a `streaming: {criterion: {password: ...}}` entry resolves as `streaming.criterion.password`. Reference it in `environment`:

```yaml
contexts:
  local:
    environment:
      CRITERION_PASSWORD: ${{ sops.streaming.criterion.password }}
```

`secrets.yaml` is auto-git-ignored, the same as `.env` (it's for local-only or pre-encryption values). Encrypt it before committing:

```bash
sops -e contexts/<context>/secrets.yaml > contexts/<context>/secrets.enc.yaml
rm contexts/<context>/secrets.yaml
```

Windsor decides whether a `secrets*.yaml` file is encrypted by its content, not its filename, so an operator's own SOPS output can carry either name. A `secrets.yaml` that still contains plaintext is refused with an explicit error rather than a raw SOPS failure, since the likely cause is a file that was never encrypted. See [Contexts directory reference](https://www.windsorcli.dev/reference/cli/contexts) for the full file layout and error text.

## 1Password CLI

Add vaults in `windsor.yaml`:

```yaml
version: v1alpha1
contexts:
  local:
    secrets:
      onepassword:
        vaults:
          personal:
            url: my.1password.com
            vault: "Personal"
          development:
            url: my-company.1password.com
            vault: "Development"
```

Then in `environment`:

```yaml
environment:
  MY_API_KEY: ${{ op.personal.myapp.api_key }}
  STRIPE_API_KEY: ${{ op.development.stripe.api_key }}
```

1Password may prompt for sign-in on first use; sessions last about 30 minutes.

## Caching

Secrets from remote providers are cached in memory. To force a refresh, start a new shell or set:

**Bash:** `NO_CACHE=true windsor init`

**PowerShell:** `$env:NO_CACHE = "true"; windsor init`

Passing `--no-cache` on any command does the same thing for that run; see [Global flags](https://www.windsorcli.dev/reference/cli/global-flags).

## Troubleshooting

Inspect a secret in the environment. On error it may appear as:

- Bash: `env | grep '<ERROR'` → for example, `MY_SECRET=<ERROR: secret not found>`
- PowerShell: `Get-ChildItem Env: | Where-Object { $_.Value -like '*<ERROR*' }`

## Security

See [Securing secrets](securing-secrets.md) for best practices and Windsor's secret-handling features.
