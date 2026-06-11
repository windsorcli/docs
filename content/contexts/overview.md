---
title: Contexts
description: How contexts work in Windsor.
---

In a Windsor project you work across different deployments or environments as **contexts**. A context can map to SDLC environments (`development`, `staging`, `production`), to parts of your infrastructure (`admin`, `web`, `observability`), or a mix (for example, `web-staging`, `web-production`).

A context typically represents a single cloud role and a single cluster role; all accounts and services in that context share the same administrative access.

## Workstation vs non-workstation contexts

Contexts named `local` or starting with `local-` are **workstation contexts**. They run a VM-backed Kubernetes cluster on your machine and use [`windsor up`](https://www.windsorcli.dev/reference/cli/commands/up) and [`windsor down`](https://www.windsorcli.dev/reference/cli/commands/down) for lifecycle. See [Workstation overview](../workstation/overview.md).

Every other context is **non-workstation** — staging, production, anything that targets real cloud infrastructure. Non-workstation contexts use [`windsor apply`](https://www.windsorcli.dev/reference/cli/commands/apply) and [`windsor destroy`](https://www.windsorcli.dev/reference/cli/commands/destroy) directly; there is no VM to bring up.

## Creating contexts

Create a Windsor project with:

```bash
windsor init
```

This creates a `local` context: a `contexts/local` folder and an entry under `contexts.local` in `windsor.yaml`.

To add another context (for example, production targeting AWS):

```bash
windsor init production --platform aws
```

This creates `contexts/production` with a basic `blueprint.yaml` and default `windsor.yaml`. The `--platform` flag drives sensible defaults — for AWS that means `terraform.backend.type: s3`; for Azure, `azurerm`; for `metal`, `docker`, or `incus`, `kubernetes` (state stored as Secrets in the cluster).

## Switching contexts

```bash
windsor set context <context-name>
```

Show the current context:

```bash
windsor get context
```

The `WINDSOR_CONTEXT` environment variable also reflects the active context, and Windsor's shell hook updates the rest of the per-context environment variables (kubeconfig, cloud profile, Talos config, etc.) on every prompt — see [Environment injection](environment-injection.md).

## Blueprint templates

Contexts are generated from blueprint templates in `contexts/_template/`. Templates define the shared base blueprint, schema, and conditional facets for every context. See [Blueprint templates](../blueprints/templates.md).

## In this section

- [Lifecycle](lifecycle.md) — how `init`, `up`, `bootstrap`, `apply`, `plan`, `destroy`, and `down` fit together
- [Environment injection](environment-injection.md) — per-context environment variables and the shell hook
- [Trusted folders](trusted-folders.md) — the trust gate that guards environment injection

## Reference

- [`windsor init`](https://www.windsorcli.dev/reference/cli/commands/init), [`windsor set`](https://www.windsorcli.dev/reference/cli/commands/set), [`windsor get`](https://www.windsorcli.dev/reference/cli/commands/get)
- [Contexts reference](https://www.windsorcli.dev/reference/cli/contexts) — full schema for `windsor.yaml` and `values.yaml`
