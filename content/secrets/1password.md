---
title: 1Password
description: Reference 1Password vault items in a context's environment with the 1Password CLI.
---

Windsor reads secrets from the [1Password CLI](https://developer.1password.com/cli/). Add vaults in `windsor.yaml`:

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

Reference an item in a context's `environment`:

```yaml
environment:
  MY_API_KEY: ${{ op.personal.myapp.api_key }}
  STRIPE_API_KEY: ${{ op.development.stripe.api_key }}
```

`op` is the 1Password provider; `personal` and `development` are the vault names configured above. 1Password may prompt for sign-in on first use; sessions last about 30 minutes.

## Caching

Secrets are cached in memory for the session. To force a refresh, start a new shell, or set:

**Bash:** `NO_CACHE=true windsor init`

**PowerShell:** `$env:NO_CACHE = "true"; windsor init`

Passing `--no-cache` on any command does the same for that run; see [Global flags](https://www.windsorcli.dev/reference/cli/global-flags).

## Troubleshooting

A secret that fails to resolve shows up in the environment as an error marker instead of a value:

- Bash: `env | grep '<ERROR'` → for example, `MY_SECRET=<ERROR: secret not found>`
- PowerShell: `Get-ChildItem Env: | Where-Object { $_.Value -like '*<ERROR*' }`

## Security

Windsor scrubs any value it reads from 1Password out of command output — Terraform runs, error messages, and `windsor env` all show `********` instead of the real value. Use `windsor env --decrypt` only when you need the plaintext in your shell; the shell hook decrypts for the session automatically, and `windsor env` without it shows cached secrets as `********`. A central vault makes rotation easy: update the item in 1Password and the next session picks it up, with nothing to re-encrypt. Limit environment injection to development secrets where you can, and close a shell once you're done with it.

A blueprint facet or Terraform input reads the same vaults through `${secret(provider, name, field)}` instead of `${{ }}` — that's how [Identity](https://www.windsorcli.dev/catalog/core/guides/identity) and the cloud platform guides set credentials without plaintext. See [Expressions](../blueprints/expressions.md).

## See also

- [SOPS](sops.md) — the other supported secrets provider
