---
title: SOPS
description: Encrypt secrets to a file with SOPS, commit them safely, and reference them in a context's environment.
---

Use [SOPS](https://github.com/getsops/sops) to encrypt secrets to a file and commit them safely. Configure SOPS and an `sops.yaml` in your project, then start plaintext locally:

```bash
$EDITOR contexts/<context>/secrets.yaml
```

Nested keys flatten to dot-path lookups, so a `streaming: {criterion: {password: ...}}` entry resolves as `streaming.criterion.password`. Reference it in a context's `environment` in `windsor.yaml`:

```yaml
version: v1alpha1
contexts:
  local:
    environment:
      CRITERION_PASSWORD: ${{ sops.streaming.criterion.password }}
```

## Encrypt and commit

`secrets.yaml` is auto-git-ignored, the same as `.env` — it's for local-only or pre-encryption values. Encrypt it before committing:

```bash
sops -e contexts/<context>/secrets.yaml > contexts/<context>/secrets.enc.yaml
rm contexts/<context>/secrets.yaml
```

Windsor decides whether a `secrets*.yaml` file is encrypted by its content, not its filename, so an operator's own SOPS output can carry either name. A `secrets.yaml` that still contains plaintext is refused with an explicit error rather than a raw SOPS failure, since the likely cause is a file that was never encrypted. See [Contexts directory reference](https://www.windsorcli.dev/reference/cli/contexts) for the full file layout and error text.

Rotating a value means decrypting, editing, and re-encrypting — there's no separate rotation command.

## Troubleshooting

A secret that fails to resolve shows up in the environment as an error marker instead of a value:

- Bash: `env | grep '<ERROR'` → for example, `MY_SECRET=<ERROR: secret not found>`
- PowerShell: `Get-ChildItem Env: | Where-Object { $_.Value -like '*<ERROR*' }`

## Security

Windsor scrubs any value it reads from SOPS out of command output — Terraform runs, error messages, and `windsor env` all show `********` instead of the real value. Use `windsor env --decrypt` only when you need the plaintext in your shell; the shell hook decrypts for the session automatically, and `windsor env` without it shows cached secrets as `********`. Limit environment injection to development secrets where you can, and close a shell once you're done with it.

A blueprint facet or Terraform input reads the same store through `${secret(provider, name, field)}` instead of `${{ }}`; see [Expressions](../blueprints/expressions.md).

## See also

- [1Password](1password.md) — the other supported secrets provider
- [Contexts directory reference](https://www.windsorcli.dev/reference/cli/contexts) — full file layout
