---
title: 1Password
description: Read 1Password items with the 1Password CLI or a service account, and use them as Terraform inputs or other secret references.
---

Windsor reads items from your 1Password vaults. It uses the 1Password CLI by default, and the 1Password SDK when `OP_SERVICE_ACCOUNT_TOKEN` is set.

Windsor needs the [1Password CLI](https://developer.1password.com/docs/cli/) (`op`, version 2.15.0 or later) on your `PATH` whenever a context declares a vault.

## Declare the vaults

Add each vault to `contexts/<context>/values.yaml`:

```yaml
secrets:
  onepassword:
    vaults:
      personal:
        url: my.1password.com
        name: "Personal"
      development:
        url: my-company.1password.com
        name: "Development"
```

Each vault has three parts:

- The key (`personal`, `development`) is the name you use as `<vault>` in a reference.
- `name` is the vault's name in 1Password.
- `url` is the sign-in address of the 1Password account that holds the vault. The CLI uses it to pick the account, so you can mix vaults from different accounts.

Set `name` and `url` for every vault.

## Reference an item

A reference gives the vault key, the item name, and the field:

```yaml
terraform:
- path: example/my-app
  inputs:
    api_token: ${secret("development", "stripe", "api_key")}
```

The field is the label of a field in the item, for example `password` or `username`, or the label of a custom field. For the places a reference can go, see [Where to use a secret](overview.md#where-to-use-a-secret).

## Sign-in

Windsor picks the client by whether `OP_SERVICE_ACCOUNT_TOKEN` is set in the environment.

- **Not set:** Windsor runs `op item get` with the account from `url`. The CLI must be signed in to that account. If you turn on the 1Password desktop app integration, `op` asks the app to unlock. Otherwise, run `op signin` first.
- **Set:** Windsor uses the 1Password SDK with that [service account](https://developer.1password.com/docs/service-accounts/). It does not prompt, which suits CI. The service account must have read access to every vault that you declare, and Windsor ignores `url`.

Each reference is a separate call, so a context with many references takes longer to start. After you update an item, a new shell picks up the new value. See [Caching](overview.md#caching).

## Troubleshooting

A reference that fails leaves an error marker in the variable. See [Troubleshooting](overview.md#troubleshooting) to find it. These are the common messages:

| Message | Cause |
|---|---|
| `no provider found for vault "<name>"` | The first argument does not match a key under `secrets.onepassword.vaults`. |
| `secret() field is required for 1Password provider` | The reference has no field. 1Password references need all three arguments. |
| `failed to retrieve secret "op://<vault>/<item>/<field>" from 1Password` | The `op` CLI could not read the item. Check the names, then run the same lookup with `op item get`. If `op` is not signed in, sign in first. |
| `failed to create 1Password client` | The service account token is missing or malformed. Check `OP_SERVICE_ACCOUNT_TOKEN`. |

## See also

- [Secrets overview](overview.md): reference syntax, caching, masking, troubleshooting
- [SOPS](sops.md): the other supported provider
