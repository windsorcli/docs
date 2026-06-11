---
title: Secrets management
description: SOPS and 1Password integration.
---

Windsor provides secrets management for API keys, passwords, and other sensitive data, with support for [SOPS](https://github.com/getsops/sops) and [1Password CLI](https://developer.1password.com/cli/).

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

Use [SOPS](https://github.com/getsops/sops) to encrypt secrets to a file and commit them safely. Configure SOPS and an `sops.yaml` in your project, then:

```bash
sops contexts/<context>/secrets.enc.yaml
```

If that file exists and is valid SOPS-encrypted, reference values in `environment`:

```yaml
contexts:
  local:
    environment:
      CRITERION_PASSWORD: ${{ sops.streaming.criterion.password }}
```

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

You may be prompted to sign in to 1Password; the session typically lasts about 30 minutes.

## Caching

Secrets from remote providers are cached in memory. To force a refresh, start a new shell or set:

**Bash:** `NO_CACHE=true windsor init`

**PowerShell:** `$env:NO_CACHE = "true"; windsor init`

## Troubleshooting

Inspect a secret in the environment. On error it may appear as:

- Bash: `env | grep '<ERROR'` → for example, `MY_SECRET=<ERROR: secret not found>`
- PowerShell: `Get-ChildItem Env: | Where-Object { $_.Value -like '*<ERROR*' }`

## Security

See [Securing secrets](securing-secrets.md) for best practices and Windsor's secret-handling features.
