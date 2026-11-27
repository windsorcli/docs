---
title: 1Password
description: Read 1Password item fields through the op CLI on a workstation or a service account in CI, and use them as Terraform inputs or other secret references.
---

<!-- ai: rough draft. Structure only; the docs owner writes the final prose from the dossier. -->

When your team already keeps its credentials in 1Password, a context can read them where they are. Windsor fetches one field of one item for each reference. On a workstation it calls the [1Password CLI](https://developer.1password.com/docs/cli/), `op`, which uses your own sign-in. In CI it uses the 1Password SDK with a [service account](https://developer.1password.com/docs/service-accounts/). Windsor requires `op` 2.15.0 or later on your `PATH` whenever a context declares a vault.

## Declare the vaults

List each vault under `secrets.onepassword.vaults` in the context's `values.yaml`:

```yaml
# contexts/production/values.yaml
secrets:
  onepassword:
    vaults:
      personal:
        url: my.1password.com
        name: Personal
      development:
        url: my-company.1password.com
        name: Development
```

The key, such as `development`, is the name a reference uses. `name` is the vault's name in 1Password. `url` is the sign-in address of the account that holds the vault, and `op` uses it to pick the account, so one context can mix vaults from several accounts. Set `name` and `url` for every vault.

## Reference an item

A 1Password reference takes three arguments: the vault key, the item name, and the field label.

```yaml
terraform:
- path: example/my-app
  inputs:
    api_token: ${secret("development", "stripe", "api_key")}
```

The field is the label shown in the item, such as `password`, `username`, or the label of a custom field. A reference without a field fails before Windsor calls `op`:

```text
The secret("development", "stripe") call names no field, which a 1Password vault needs.
```

For the places a reference can go, see [Where to use a secret](overview.md#where-to-use-a-secret).

## Sign-in

Windsor picks the client from the environment. When `OP_SERVICE_ACCOUNT_TOKEN` is not set, it uses `op`. When it is set, it uses the SDK.

### On a workstation

For each reference, Windsor runs `op item get` against the account from `url`, so `op` must be signed in to that account. With the 1Password desktop app integration on, `op` asks the app to unlock it. Otherwise, run `op signin --account <url>` first. When the app waits on you, Windsor prints a reminder after 3 seconds:

```text
Waiting for 1Password (my.1password.com) to resolve secret "op://Development/stripe/api_key". Approve the request in the 1Password app if it is asking.
```

Each call gives up after 30 seconds. To wait longer, set `WINDSOR_OP_TIMEOUT` to a duration such as `45s` or `2m`.

### In CI

Set `OP_SERVICE_ACCOUNT_TOKEN` to a service account token. Windsor then reads each reference through the SDK and never prompts. The service account must have read access to every vault you declare. The SDK ignores `url`, because the token already names the account.

## Check access before a run

Commands that run Terraform, such as `plan`, `apply`, `up`, and `destroy`, check each 1Password account before they change anything. For `op` the check is `op whoami --account <url>`. For a service account, it lists the vaults the token can see. A failed check stops the command and reports every account that failed:

```text
1Password isn't signed in for my-company.1password.com. op said: [ERROR] 2026/11/26 19:54:07 account is not signed in
Run `op signin --account my-company.1password.com`.
```

## Performance

Each reference is a separate call to `op` or the SDK, so a context with many references takes longer to start a shell or a command. The shell hook caches each value for the life of the shell. After you update an item, a new shell, or one prompt with `NO_CACHE=1`, picks up the new value. See [Caching](overview.md#caching).

## Troubleshooting

A reference that fails leaves an error marker in its variable. See [Troubleshooting](overview.md#troubleshooting) to find the markers. Each message names the cause, then quotes what `op` said:

| Message starts with | Cause |
|---|---|
| `No secrets provider handles the vault "<key>".` | The first argument is not a key under `secrets.onepassword.vaults`. |
| `The secret(...) call names no field` | The reference has two arguments. 1Password needs the field too. |
| `1Password has no such item or vault` | The item name, or the vault's `name`, does not match 1Password. |
| `1Password has no such field` | The item has no field with that label. |
| `1Password has no account <url>.` | `op` knows no account at `url`. Check the `url`, or run `op account add --address <url>`. |
| `1Password isn't signed in for <url>.` | Run `op signin --account <url>`. |
| `Couldn't reach the 1Password desktop app` | Unlock 1Password, and check that Settings > Developer > Integrate with 1Password CLI is on. |
| `Timed out after 30s waiting for 1Password` | Nobody approved the request in time. Approve it, or raise `WINDSOR_OP_TIMEOUT`. |
| `1Password rejected the service account token` | `OP_SERVICE_ACCOUNT_TOKEN` is not a valid service account token. |

<!-- ai: a typo in `url` gives "no account" from a reference but "isn't signed in" from the access check. Worth a sentence? See the 1Password dossier, Known problems. -->

## See also

- [Secrets overview](overview.md): reference syntax, where references go, caching, masking
- [SOPS](sops.md): the other provider
