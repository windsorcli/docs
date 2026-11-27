---
title: Trusted folders
description: Windsor reads a project's configuration only from folders you've trusted. How to trust one, what to read first, and how to undo it.
---

A Windsor project determines which environment variables are injected or overridden. Its `values.yaml` can export shell variables, name a secrets provider, and point Terraform at a state backend, and its blueprint can pull modules from any OCI registry. To protect your system, Windsor will not configure your environment until you trust the project. Several commands will not function until you do.

## Trust a project

You trust a project by running [`windsor init`](https://www.windsorcli.dev/reference/cli/commands/init) or [`windsor bootstrap`](https://www.windsorcli.dev/reference/cli/commands/bootstrap).

```bash
windsor init
```

Windsor records the *project root*, the directory that holds `windsor.yaml`. Trust covers the root and every directory under it, so you run it once per project, from the root or any subdirectory.

## How trust protects you

In an untrusted project, any command that reads the project's configuration is blocked. This includes [`windsor env`](https://www.windsorcli.dev/reference/cli/commands/env), [`windsor exec`](https://www.windsorcli.dev/reference/cli/commands/exec), [`windsor show`](https://www.windsorcli.dev/reference/cli/commands/show), [`windsor plan`](https://www.windsorcli.dev/reference/cli/commands/plan), and [`windsor up`](https://www.windsorcli.dev/reference/cli/commands/up). Each one prints an error and exits.

```text
error: not in a trusted directory
hint: Run windsor init to trust this directory, if it is a Windsor project.
```

The [shell hook](environment-injection.md#set-up-the-shell-hook) runs `windsor env` in a mode that never fails, so in an untrusted project it exports nothing. At the first prompt there, it unsets the variables the last trusted project set.

## Read before you trust

Treat a project you didn't write the way you'd treat a downloaded script. Read these files before you run `windsor init`:

1. `windsor.yaml`, at the project root. Its `environment:` block may set environment variables.
2. `contexts/<context>/blueprint.yaml`. Its `sources` entries can pull OCI artifacts from any registry.
3. `contexts/<context>/values.yaml`. Look for an `environment:` block, an unfamiliar `terraform.backend`, a secrets provider you didn't expect, and endpoints, registries, or DNS overrides you don't recognize.
4. `contexts/_template/`, if the project has one. Its facets hold expressions that run when Windsor composes the blueprint, so read an unfamiliar facet as you'd read a script.

`windsor show blueprint` is blocked in an untrusted project, so you cannot use it to preview the composed blueprint first. Read the files and validate your supply chain.

## Remove trust

To remove trust, delete the project folder's entry from `~/.config/windsor/.trusted`.

## Under the hood

The trust list is stored at `~/.config/windsor/.trusted`, a plain text file with mode 0600 containing one absolute path per line. `init` and `bootstrap` append the project root to this file if it is not already trusted.

Before a protected command reads the project, Windsor finds the project root by walking up from the current directory, up to 10 levels, looking for `windsor.yaml` or `windsor.yml`. The project is trusted when its root, or a directory above it, is in the trust file. Windsor compares whole path components, so a listed `/work/proj` does not trust `/work/proj-other`.

When Windsor finds no `windsor.yaml`, it runs in global mode with `~/.config/windsor` as the root. Global mode does not inject environment variables into your shell, and trusts any blueprint you bootstrap.

```bash
cat ~/.config/windsor/.trusted
```

## Reference

- [Environment injection](environment-injection.md): what trust gates day to day
- [SOPS](../secrets/sops.md), [1Password](../secrets/1password.md): the secrets providers a `values.yaml` can name
- [`init`](https://www.windsorcli.dev/reference/cli/commands/init), [`bootstrap`](https://www.windsorcli.dev/reference/cli/commands/bootstrap), [`env`](https://www.windsorcli.dev/reference/cli/commands/env), [`hook`](https://www.windsorcli.dev/reference/cli/commands/hook)
