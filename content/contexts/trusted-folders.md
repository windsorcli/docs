---
title: Trusted folders
description: Windsor only injects environment in folders you've trusted, and how to review a project before you trust it.
---

A Windsor project drives Terraform, secrets backends, and shell environment injection from files in its repository. If `cd`-ing into a project were enough to evaluate those files, cloning someone else's repo would be an environment-injection vector. Windsor closes that gap with an explicit trust step: [`windsor env`](https://www.windsorcli.dev/reference/cli/commands/env) and the [shell hook](https://www.windsorcli.dev/reference/cli/commands/hook) load nothing from a project until you've trusted it.

## Trust a project

Running `windsor init` in a project marks its directory trusted, and that's the only way a directory becomes trusted:

```bash
windsor init
```

Any subdirectory of a trusted folder inherits the trust, so you trust the project root once.

## Review before you trust

Trust a project you didn't author the way you'd read a script before running it. Before `windsor init`, look at:

1. **`windsor.yaml`**: the project root config. Watch for unfamiliar `terraform.backend` settings, unexpected secrets backends, or overrides that point at untrusted endpoints.
2. **`contexts/<context>/blueprint.yaml`**: the blueprint. Check `repository.url` and any `sources` entries; these can pull external OCI artifacts.
3. **`contexts/<context>/values.yaml`**: context values. Look for cluster endpoints, registry URLs, or DNS overrides that don't match what you expect.
4. **`contexts/_template/`**: facets, schema, metadata. Facets carry expressions that run during composition; read an unfamiliar facet like a script.

One command pulls the composition together for review:

```bash
windsor show blueprint --raw
```

`--raw` keeps deferred expressions visible, so you can read what they do before any Terraform runs.

## Remove trust

To untrust a folder, remove its line from `~/.config/windsor/.trusted`. Windsor re-prompts the next time you `windsor init` in that path:

```bash
sed -i.bak '\|/path/to/project|d' ~/.config/windsor/.trusted
```

## Under the hood

Trusted directories live in `$HOME/.config/windsor/.trusted`, a plain newline-delimited file. Each line is an absolute path to a project root you've run `windsor init` in, and any subdirectory of a listed path inherits the trust. Inspect or edit it directly:

```bash
cat ~/.config/windsor/.trusted
```

Commands that don't inject environment variables work in any directory, trusted or not: [`version`](https://www.windsorcli.dev/reference/cli/commands/version), [`hook`](https://www.windsorcli.dev/reference/cli/commands/hook), [`get`](https://www.windsorcli.dev/reference/cli/commands/get). The shell hook itself runs everywhere too; in an untrusted directory it emits nothing.

## Reference

- [Environment injection](environment-injection.md) — what trust gates
- [Securing secrets](../deployment/securing-secrets.md)
- [`init`](https://www.windsorcli.dev/reference/cli/commands/init), [`env`](https://www.windsorcli.dev/reference/cli/commands/env), [`hook`](https://www.windsorcli.dev/reference/cli/commands/hook)
