---
title: Contexts
description: Contexts are Windsor's named environments (local, staging, production), each mapping to a cloud role and a cluster.
---

A **context** is a named environment that bundles a cluster, a cloud profile, and a secrets backend. Switching context switches all of them at once.

Contexts can map to SDLC stages (`development`, `staging`, `production`), to parts of your infrastructure (`admin`, `web`, `observability`), or a mix (`web-staging`, `web-production`). A context typically represents a single cloud role and a single cluster role: everything in it shares the same administrative access.

## Workstation vs non-workstation

How you operate a context depends on whether it runs on your machine.

A context named `local`, or starting with `local-`, is a **workstation context**. It runs a VM-backed Kubernetes cluster on your machine and uses [`windsor up`](https://www.windsorcli.dev/reference/cli/commands/up) and [`windsor down`](https://www.windsorcli.dev/reference/cli/commands/down) for its lifecycle. See [Workstation overview](../workstation/overview.md).

Staging, production, and anything targeting real cloud infrastructure are **non-workstation** contexts. With no local VM, they use [`windsor apply`](https://www.windsorcli.dev/reference/cli/commands/apply) and [`windsor destroy`](https://www.windsorcli.dev/reference/cli/commands/destroy) directly. [Lifecycle](lifecycle.md) covers both paths.

## Create a context

`windsor init` creates a project with a `local` context: a `contexts/local` folder and a `contexts.local` entry in `windsor.yaml`:

```bash
windsor init
```

To add another, name it and point it at a platform. This creates production targeting AWS, with a starter `blueprint.yaml` and `windsor.yaml`:

```bash
windsor init production --platform aws
```

`--platform` drives the defaults: AWS sets `terraform.backend.type: s3`; Azure sets `azurerm`; `metal`, `docker`, and `incus` use `kubernetes` (state stored as Secrets in the cluster).

New contexts are generated from blueprint templates in `contexts/_template/`, which define the shared base blueprint, schema, and conditional facets every context inherits. See [Blueprint templates](../blueprints/templates.md).

## Switch contexts

Set the active context, then check it:

```bash
windsor set context <context-name>
windsor get context
```

`WINDSOR_CONTEXT` reflects the active context. On your next prompt, the shell hook updates the per-context environment, including kubeconfig and the cloud profile. See [Environment injection](environment-injection.md).

## In this section

- [Lifecycle](lifecycle.md) — how `init`, `up`, `bootstrap`, `apply`, `plan`, `destroy`, and `down` fit together
- [Environment injection](environment-injection.md) — per-context environment variables and the shell hook
- [Trusted folders](trusted-folders.md) — the trust gate that guards environment injection

## Reference

- [`windsor init`](https://www.windsorcli.dev/reference/cli/commands/init), [`windsor set`](https://www.windsorcli.dev/reference/cli/commands/set), [`windsor get`](https://www.windsorcli.dev/reference/cli/commands/get)
- [Contexts reference](https://www.windsorcli.dev/reference/cli/contexts) — full schema for `windsor.yaml` and `values.yaml`
