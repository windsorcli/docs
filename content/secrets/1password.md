---
title: 1Password
description: Read 1Password item fields through the op CLI on a workstation or a service account in CI, and use them as Terraform inputs or other secret references.
---

- for teams that already keep credentials in 1Password (scope; no claim)
- one field of one item per reference (live, claim 4)
- workstation: the `op` CLI with the user's own sign-in; link `https://developer.1password.com/docs/cli/` (live, claim 4)
- CI: the 1Password SDK with a service account; link `https://developer.1password.com/docs/service-accounts/` (live, claim 9; bogus token only)
- `op` 2.15.0 or later on `PATH` whenever a context declares a vault (source, claim 3)

## Declare the vaults

- each vault an entry under `secrets.onepassword.vaults` in the context's `values.yaml` (live, claim 1)
- the entry's key is the first `secret()` argument (live, claim 1)
- `name`: the vault's name in 1Password (live, claim 1)
- `url`: sign-in address of the account holding the vault (live, claim 1)
- `op` picks the account by `url` through `--account`, so one context can mix accounts (source, claim 5; one account run)
- set both on every vault (live, claim 1)
- `id` replaces the key as the alias; the reference calls it the vault ID; leave off or ask (source, claim 2, Known problems)

## Reference an item

- three arguments: vault key, item name, field label (live, overview claim 3)
- field: the label shown in the item: `password`, `username`, a custom field label (live, claim 6: custom field on a Secure Note)
- no field: fails before any `op` call, `The secret("<vault>", "<item>") call names no field, which a 1Password vault needs.` (live, claim 12)
- where references go: link `overview.md#where-to-use-a-secret`

## Sign-in

- client from the environment: no `OP_SERVICE_ACCOUNT_TOKEN` → `op`; set → SDK (live, Defaults)

### On a workstation

- per reference, `op item get --vault <name> --fields <field> --reveal --account <url> -- <item>` (live, claim 4)
- `op` must be signed in to the `url` account (source, claim 5)
- desktop app integration on: `op` asks the app to unlock (source, claim 7)
- otherwise `op signin --account <url>` first (live: preflight remediation text)
- after 3 s of waiting, the approval reminder (source, claim 7)
- each call times out after 30 s (source, claim 8)
- `WINDSOR_OP_TIMEOUT` in Go duration syntax, `45s`, `2m` (live, claim 8: `1ms`)

### In CI

- `OP_SERVICE_ACCOUNT_TOKEN` set to a service account token (live, claim 9)
- SDK path, never prompts (source, claim 9)
- the service account must read every declared vault (source, claim 9)
- the SDK ignores `url`; the token determines the account (source, claim 9)
- one token for every vault; vaults in two service accounts cannot mix (source, Limits)

## Check access before a run

- `plan`, `apply`, `up`, `destroy`, `bootstrap`, `upgrade` check each account once before changing anything (live, claim 10)
- `op`: `op whoami --account <url>`; SDK: a vault list (source, claim 10)
- step label `Checking 1Password access (<url>)`, or `(service account)` (live, claim 10)
- a failure stops the command and lists every account that failed (live, claim 10)
- shipped in v0.10.0 (source, d01364c8e)

## Performance

- each reference is a separate `op` or SDK call; many references slow a new shell or a command (source, claim 11)
- the hook caches each value for the life of the shell (live via SOPS, claim 11)
- after an item changes: a new shell, or one prompt with `NO_CACHE=1`; link `overview.md#caching` (live via SOPS, claim 11)

## Troubleshooting

- a failed reference leaves an error marker; finding markers: link `overview.md#troubleshooting` (live, overview claim 23)
- each message names the cause, then `op said: <stderr>` (live, claim 13)
- `op` stderr truncated to 300 characters (source, Limits)
- the message table (Prepared blocks)
- a typo in `url` gives "no account" from a reference but "isn't signed in" from the access check (live, Known problems)

## See also

- `overview.md`: reference syntax, where references go, caching, masking
- `sops.md`: the other provider
