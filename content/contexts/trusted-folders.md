---
title: Trusted folders
description: Windsor loads a project's configuration only from folders you've trusted. How to trust one, what to read first, and how to undo it.
---

A Windsor project runs Terraform, resolves secrets, and sets shell variables from files in its repository. These activities take place in response to the contents in the project folder. It is important that you
trust the project you're working with before executing Windsor commands. You must trust a project before 
environment injection will activate.

## Trust a project

[`windsor init`](https://www.windsorcli.dev/reference/cli/commands/init) marks the current directory trusted, as does [`windsor bootstrap`](https://www.windsorcli.dev/reference/cli/commands/bootstrap):

```bash
windsor init
```

Trust covers the folder and everything under it, so you only need to do this once per project.

## What trust protects

In an untrusted project, the [shell hook](environment-injection.md#set-up-the-shell-hook) stays silent, and every command that reads the project stops with an error. That includes [`windsor env`](https://www.windsorcli.dev/reference/cli/commands/env), [`windsor exec`](https://www.windsorcli.dev/reference/cli/commands/exec), [`windsor show`](https://www.windsorcli.dev/reference/cli/commands/show), and [`windsor plan`](https://www.windsorcli.dev/reference/cli/commands/plan):

```text
Error: not in a trusted directory. If you are in a Windsor project, run 'windsor init' to approve
```

Commands that don't read a project run anywhere: [`version`](https://www.windsorcli.dev/reference/cli/commands/version), [`hook`](https://www.windsorcli.dev/reference/cli/commands/hook), and [`get`](https://www.windsorcli.dev/reference/cli/commands/get).

## Read before you trust

Treat a project you didn't write the way you'd treat a script you downloaded, and read it first. These are the files to open:

1. **`windsor.yaml`**, the project config. Look for an unfamiliar `terraform.backend`, a secrets backend you didn't expect, or overrides that point at endpoints you don't recognize.
2. **`contexts/<context>/blueprint.yaml`**, the blueprint. The `sources` entries can pull OCI artifacts from other registries.
3. **`contexts/<context>/values.yaml`**, the context's values. Check cluster endpoints, registry URLs, and DNS overrides against what you'd expect.
4. **`contexts/_template/`**, if the project has one. Facets hold expressions that run when the blueprint is composed, so read an unfamiliar facet like a script.

`windsor show blueprint` is gated too, so you can't use it to preview the composition before you run `init`. Read the files themselves.

## Remove trust

Delete the project's line from `~/.config/windsor/.trusted`. Running `windsor init` there trusts it again:

```bash
sed -i.bak '\|/path/to/project|d' ~/.config/windsor/.trusted
```

## Under the hood

`~/.config/windsor/.trusted` is a plain text file with one absolute project-root path per line, added each time you run `init` or `bootstrap`. A project is trusted when its root is one of those paths or sits inside one. Read or edit the file directly:

```bash
cat ~/.config/windsor/.trusted
```

## Reference

- [Environment injection](environment-injection.md): what trust gates day to day
- [SOPS](../secrets/sops.md), [1Password](../secrets/1password.md): the secrets backends a `windsor.yaml` can name
- [`init`](https://www.windsorcli.dev/reference/cli/commands/init), [`bootstrap`](https://www.windsorcli.dev/reference/cli/commands/bootstrap), [`env`](https://www.windsorcli.dev/reference/cli/commands/env), [`hook`](https://www.windsorcli.dev/reference/cli/commands/hook)
