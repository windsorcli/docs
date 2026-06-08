---
title: Trusted folders
description: Windsor only injects environment in folders you trust.
---

A Windsor project drives Terraform, secrets backends, and shell environment injection from files in your repository. If you `cd` into a project you didn't author, those files would otherwise be evaluated automatically — a clear environment-injection vector.

Windsor mitigates this by gating injection behind an explicit trust step. You must run `windsor init` in a project before [`windsor env`](/reference/cli/commands/env) (and the [shell hook](/reference/cli/commands/hook)) will load anything from it.

## How trust is recorded

Trusted directories are stored in `$HOME/.config/windsor/.trusted`. Each line is an absolute path to a project root that you have run `windsor init` in. Any subdirectory of a trusted folder inherits the trust.

The file is a plain newline-delimited list — inspect or edit it directly:

```bash
cat ~/.config/windsor/.trusted
```

## Reviewing a project before you trust it

Before running `windsor init` in a project you didn't author, review:

1. **`windsor.yaml`** — the project root config. Watch for unfamiliar `terraform.backend` settings, unexpected secrets backends, or overrides that point at untrusted endpoints.
2. **`contexts/<context>/blueprint.yaml`** — the blueprint. Check the `repository.url` and any `sources` entries; these can pull external OCI artifacts.
3. **`contexts/<context>/values.yaml`** — context values. Look for cluster endpoints, registry URLs, or DNS overrides that don't match what you expect.
4. **`contexts/_template/`** — facets, schema, metadata. Facets carry expressions that run during composition; an unfamiliar facet should be read like a script.

A useful drive-by command:

```bash
windsor show blueprint --raw
```

`--raw` keeps deferred expressions visible so you can read what they do before any Terraform runs.

## Removing trust

To untrust a folder, edit `~/.config/windsor/.trusted` and remove the line. Windsor will re-prompt the next time you `windsor init` in that path.

```bash
sed -i.bak '\|/path/to/project|d' ~/.config/windsor/.trusted
```

## What still works without trust

Commands that don't inject environment variables — [`version`](/reference/cli/commands/version), [`hook`](/reference/cli/commands/hook), [`get`](/reference/cli/commands/get) — work in any directory. So does the shell hook itself; it emits nothing for untrusted directories.

## See also

- [Securing secrets](/deployment/securing-secrets)
- [Environment injection](/contexts/environment-injection), [Environment reference](/reference/cli/environment)
- [`init`](/reference/cli/commands/init), [`env`](/reference/cli/commands/env), [`hook`](/reference/cli/commands/hook)
