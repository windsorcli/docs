---
title: Overview
description: A context is a named environment (local, staging, production) with its own blueprint, values, and credentials, and Windsor tracks which one is active.
---

It is common to reuse infrastructure code across several targets. Testing is often performed in
a dedicated staging environment. Duplicates of production infrastructure may target
different regions, or be dedicated to a single-tenant customer.

Across each of the above targets, authentication, endpoints, and input parameters vary. Windsor
keeps this organized by bundling these collections individually as contexts. These contexts are referenced when running commands. Automatic environment injection configures your tool chain
to also operate against a common target, so your `kubectl` or `aws` commands target the same
infrastructure.

Windsor organizes context files under `<project-root>/contexts/<context-name>/`.

```text
windsor.yaml                     project root; a version stamp
contexts/
└── local/
    ├── blueprint.yaml           this context's blueprint
    ├── values.yaml              values that feed the schema
    ├── .gitignore               keeps sensitive context files out of commits
    ├── secrets.enc.yaml         SOPS-encrypted secrets, safe to commit
    ├── .env                     git-ignored environment variables
    ├── terraform/               <component>.tfvars overrides for terraform components
    ├── patches/                 <component>/patch.yaml patches for kustomize components
    ├── .kube/config             kubeconfig, written by windsor up
    └── .talos/config            talosconfig, written by windsor up
.windsor/
├── context                      the active context name
└── contexts/local/              generated Terraform module shims, workstation config, and the stack lock
```

A context that targets a cloud platform also gets `.aws/`, `.azure/`, or `.gcp/` for that CLI's config, and a `backend.tfvars` once the backend component has run.

To create a new context, run `windsor init <context-name> --platform <platform>`. This command generates a `blueprint.yaml` file and a `values.yaml` specific to the platform you specified.

To switch contexts, run `windsor set context <context-name>`. You may also pass the `--context` flag to most windsor commands.

Contexts usually map to an SDLC stage (`development`, `staging`, `production`), a slice of infrastructure (`admin`, `web`, `observability`), or both, like `web-staging`.

## Workstation vs non-workstation

A context named `local`, or starting with `local-`, is a **workstation context**. It runs a VM-backed Kubernetes cluster on your machine and uses [`windsor up`](https://www.windsorcli.dev/reference/cli/commands/up) and [`windsor down`](https://www.windsorcli.dev/reference/cli/commands/down). See [Workstation overview](../workstation/overview.md).

Every other context is **non-workstation**: staging, production, anything on real cloud infrastructure. It has no local VM and uses [`windsor apply`](https://www.windsorcli.dev/reference/cli/commands/apply) and [`windsor destroy`](https://www.windsorcli.dev/reference/cli/commands/destroy) directly.

## Create a context

`windsor init` creates the project and a `local` context: a `contexts/local` folder with a starter `blueprint.yaml`, plus a minimal `windsor.yaml` at the project root on the first run:

```bash
windsor init
```

To add another, name it and choose a platform. This creates `contexts/production/` targeting AWS, with its own `blueprint.yaml`:

```bash
windsor init production --platform aws
```

[`windsor get contexts`](https://www.windsorcli.dev/reference/cli/commands/get-contexts) lists contexts by scanning `contexts/`, and `.windsor/context` records the active one. The root `windsor.yaml` is a version stamp. It gains a `contexts:` map only if you add one for legacy per-context overrides, and a new context never needs it.

`--platform` sets the backend default: `s3` for AWS, `azurerm` for Azure, `gcs` for GCP, and `kubernetes` (state stored as Secrets in the cluster) for `metal`, `docker`, `incus`, `hetzner`, `hyperv`, and `vsphere`.

Every context inherits from a blueprint template: the base blueprint, the schema, and the conditional facets. If you author your own blueprint, the template lives in `contexts/_template/`. See [Blueprint templates](../blueprints/templates.md).

## Switch contexts

Set the active context, then check it:

```bash
windsor set context <context-name>
windsor get context
```

`windsor set context` writes the name to `.windsor/context` and sets `WINDSOR_CONTEXT` for the current process. By your next prompt, the shell hook has refreshed the per-context environment, including kubeconfig and the cloud profile. See [Environment injection](environment-injection.md).

## In this section

- [Environment injection](environment-injection.md): per-context environment variables and the shell hook
- [Trusted folders](trusted-folders.md): the trust gate that guards environment injection

## Reference

- [`windsor init`](https://www.windsorcli.dev/reference/cli/commands/init), [`windsor set`](https://www.windsorcli.dev/reference/cli/commands/set), [`windsor get`](https://www.windsorcli.dev/reference/cli/commands/get)
- [Contexts reference](https://www.windsorcli.dev/reference/cli/contexts): on-disk layout of `contexts/`, including what lives in each context's `values.yaml`
- [Configuration reference](https://www.windsorcli.dev/reference/cli/configuration): full schema for values a context accepts
