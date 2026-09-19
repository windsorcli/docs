---
title: Overview
description: Contexts are Windsor's named environments (local, staging, production), each mapping to a cloud role and a cluster.
---

A context is a name, like `local` or `staging`, for one cluster and one cloud account. It's a directory, `contexts/<name>/`, with a blueprint, Terraform state, and `values.yaml` inside. Each tool keeps its own credentials there too, like kubeconfig or cloud CLI config. Windsor tracks the active one in `.windsor/context`.

Switch context, and `kubectl`, `terraform`, your cloud CLI, and `windsor` itself all follow it. Run `windsor apply` in `staging`, and only `staging` changes.

`direnv` and `mise` do something similar, per directory instead of per name.

A context often names an SDLC stage (`development`, `staging`, `production`) or a slice of infrastructure (`admin`, `web`, `observability`), sometimes both, like `web-staging`. It usually covers one cloud role and one cluster role, so everything inside shares the same access.

## Workstation vs non-workstation

How you operate a context depends on whether it runs on your machine.

A context named `local`, or starting with `local-`, is a **workstation context**. It runs a VM-backed Kubernetes cluster on your machine and uses [`windsor up`](https://www.windsorcli.dev/reference/cli/commands/up) and [`windsor down`](https://www.windsorcli.dev/reference/cli/commands/down) for its lifecycle. See [Workstation overview](../workstation/overview.md).

Staging, production, and anything targeting real cloud infrastructure are **non-workstation** contexts. With no local VM, they use [`windsor apply`](https://www.windsorcli.dev/reference/cli/commands/apply) and [`windsor destroy`](https://www.windsorcli.dev/reference/cli/commands/destroy) directly. [Command model](../provisioning/workflow.md) covers both paths.

## Create a context

`windsor init` creates a project with a `local` context: a `contexts/local` folder with a starter `blueprint.yaml`, and, on the very first run, a minimal `windsor.yaml` at the project root:

```bash
windsor init
```

To add another, name it and point it at a platform. This creates `contexts/production/` targeting AWS, with its own `blueprint.yaml`:

```bash
windsor init production --platform aws
```

[`windsor get contexts`](https://www.windsorcli.dev/reference/cli/commands/get-contexts) lists them by scanning the `contexts/` directory directly, and `.windsor/context` records which one is active. Root `windsor.yaml` stays a thin version stamp; it only grows a `contexts:` map if you add one yourself, for legacy per-context overrides. A new context never needs one.

`--platform` drives the defaults: AWS sets `terraform.backend.type: s3`; Azure sets `azurerm`; GCP sets `gcs`; `metal`, `docker`, `incus`, `hetzner`, `hyperv`, and `vsphere` use `kubernetes` (state stored as Secrets in the cluster).

New contexts are generated from blueprint templates in `contexts/_template/`, which define the shared base blueprint, schema, and conditional facets every context inherits. See [Blueprint templates](../blueprints/templates.md).

## Switch contexts

Set the active context, then check it:

```bash
windsor set context <context-name>
windsor get context
```

`windsor set context` writes the active context to `.windsor/context`, sets `WINDSOR_CONTEXT` for the current process, and by your next prompt has the shell hook refresh the per-context environment, including kubeconfig and the cloud profile. See [Environment injection](environment-injection.md).

## In this section

- [Environment injection](environment-injection.md) — per-context environment variables and the shell hook
- [Trusted folders](trusted-folders.md) — the trust gate that guards environment injection

## Reference

- [`windsor init`](https://www.windsorcli.dev/reference/cli/commands/init), [`windsor set`](https://www.windsorcli.dev/reference/cli/commands/set), [`windsor get`](https://www.windsorcli.dev/reference/cli/commands/get)
- [Contexts reference](https://www.windsorcli.dev/reference/cli/contexts) — on-disk layout of `contexts/`, including what lives in each context's `values.yaml`
- [Configuration reference](https://www.windsorcli.dev/reference/cli/configuration) — full schema for values a context accepts
