---
title: Trusted folders
description: Windsor reads a project's configuration only from folders you've trusted. How to trust one, what to read first, and how to undo it.
---

A Windsor project decides what Windsor runs. Its `values.yaml` can export shell variables, name a secrets provider, and point Terraform at a state backend, and its blueprint can pull modules from any OCI registry. Windsor reads none of it until you trust the project. Until then, gated commands stop with an error and the shell hook stays silent.

## Trust a project

You trust a project by running [`windsor init`](https://www.windsorcli.dev/reference/cli/commands/init) in it. [`windsor bootstrap`](https://www.windsorcli.dev/reference/cli/commands/bootstrap) trusts it too.

```bash
windsor init
```

Windsor records the *project root*, the directory that holds `windsor.yaml`, not the directory you ran the command in. Trust covers the root and every directory under it, so you run this once per project, from any subdirectory.

## What trust protects

In an untrusted project, any command that reads the project's configuration stops before it reads it. This includes [`windsor env`](https://www.windsorcli.dev/reference/cli/commands/env), [`windsor exec`](https://www.windsorcli.dev/reference/cli/commands/exec), [`windsor show`](https://www.windsorcli.dev/reference/cli/commands/show), [`windsor plan`](https://www.windsorcli.dev/reference/cli/commands/plan), and [`windsor up`](https://www.windsorcli.dev/reference/cli/commands/up). Each one prints the same two lines and exits 1.

```text
error: not in a trusted directory
hint: Run windsor init to trust this directory, if it is a Windsor project.
```

The [shell hook](environment-injection.md#set-up-the-shell-hook) runs `windsor env` in a mode that never fails, so in an untrusted project it prints nothing. Variables from the last trusted project stay set in the shell.

Some commands never read a project's configuration, and they run anywhere: `version`, `hook`, `get context`, `get contexts`, and `set context`. `set context` writes the context name to `.windsor/context` and does nothing else.

## Read before you trust

Treat a project you didn't write the way you'd treat a script you downloaded. Read these files before you run `windsor init` in it.

1. `windsor.yaml`, at the project root. Windsor writes it with one line, `version: v1alpha2`. Read anything more the way you'd read a `values.yaml`.
2. `contexts/<context>/blueprint.yaml`. Its `sources` entries can pull OCI artifacts from any registry.
3. `contexts/<context>/values.yaml`. Look for an `environment:` block, an unfamiliar `terraform.backend`, a secrets provider you didn't expect, and endpoints, registries, or DNS overrides you don't recognize.
4. `contexts/_template/`, if the project has one. Its facets hold expressions that run when Windsor composes the blueprint, so read an unfamiliar facet as you'd read a script.

`windsor show blueprint` is gated, so it cannot preview the composed blueprint first. Read the files.

## Remove trust

Delete the project's line from `~/.config/windsor/.trusted`. Anchor the pattern, or `sed` also deletes the lines for other projects whose path starts with this one:

```bash
sed -i.bak '\|^/path/to/project$|d' ~/.config/windsor/.trusted
```

Gated commands fail again. Running `windsor init` in the project trusts it again.

## Under the hood

The trust list is `~/.config/windsor/.trusted`, a plain text file with mode 0600 and one absolute path per line. `init` and `bootstrap` append the project root when it is not already listed.

Before a gated command reads the project, Windsor finds the project root by walking up from the current directory, at most 10 levels, looking for `windsor.yaml` or `windsor.yml`. The project is trusted when its root equals a listed path or sits under one. Windsor compares whole path components, so a listed `/work/proj` does not trust `/work/proj-other`.

When Windsor finds no `windsor.yaml`, it runs in global mode with `~/.config/windsor` as the root. Global mode needs no trust.

```bash
cat ~/.config/windsor/.trusted
```

## Reference

- [Environment injection](environment-injection.md): what trust gates day to day
- [SOPS](../secrets/sops.md), [1Password](../secrets/1password.md): the secrets providers a `values.yaml` can name
- [`init`](https://www.windsorcli.dev/reference/cli/commands/init), [`bootstrap`](https://www.windsorcli.dev/reference/cli/commands/bootstrap), [`env`](https://www.windsorcli.dev/reference/cli/commands/env), [`hook`](https://www.windsorcli.dev/reference/cli/commands/hook)
