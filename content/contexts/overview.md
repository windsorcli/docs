---
title: Overview
description: A context is a named environment (local, staging, production) with its own blueprint, values, and credentials, and Windsor tracks which one is active.
---

Windsor uses **contexts** to make it easier to work across several environments.

It is common to reuse infrastructure code across several environments. For example, tests are often run against dedicated staging infrastructure. Replicas of production infrastructure may run in different regions, or be dedicated to single-tenant customers.

Across each of the above targets, authentication, endpoints, and input parameters vary. Windsor
keeps this organized by bundling these collections individually as contexts. Contexts are referenced when running commands that target a particular environment. Automatic environment variable injection configures your tool chain (for example, the `kubectl` or `aws` CLIs) to target the current context.

Contexts usually map to an SDLC stage (`development`, `staging`, `production`), a slice of infrastructure (`admin`, `web`, `observability`), or both, like `web-staging`.

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

## Create a context

`windsor init` creates the project and a `local` context: a `contexts/local` folder with a starter `blueprint.yaml`, plus a minimal `windsor.yaml` at the project root on the first run:

```bash
windsor init
```

To add another, use a different name (for example, `production`) and choose a platform. This command creates `contexts/production/` targeting AWS, with its own `blueprint.yaml`:

```bash
windsor init production --platform aws
```

## Switch contexts

Set the active context, then check it:

```bash
windsor set context <context-name>
windsor get context
```

`windsor set context` writes the context name to `.windsor/context` and sets `WINDSOR_CONTEXT` for the current process. By your next prompt, the shell hook has refreshed the per-context environment, including kubeconfig and the cloud profile. See [Environment injection](environment-injection.md).

## Workstation vs. deployed contexts

Contexts that represent a local workstation work a little differently, so keep a few things in mind.

A **workstation context**, named `local` or starting with `local-`, runs a Kubernetes cluster in a VM on your machine. Windsor starts and stops that VM. Every other context, like `staging` or `production`, is **deployed**. It targets a cloud, a hypervisor, or bare metal, so there's no VM to start and Windsor provisions the infrastructure directly.

|                 | Workstation                                                                                          | Deployed                                                                           |
| --------------- | ---------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------- |
| Cluster runs on | A VM on your machine                                                                                 | A cloud, hypervisor, or bare metal                                                 |
| First run       | [`windsor up`](https://www.windsorcli.dev/reference/cli/commands/up)                                 | [`windsor bootstrap`](https://www.windsorcli.dev/reference/cli/commands/bootstrap) |
| Tear down       | [`windsor destroy`](https://www.windsorcli.dev/reference/cli/commands/destroy), then [`windsor down`](https://www.windsorcli.dev/reference/cli/commands/down) | `windsor destroy`                                                                  |

Read more about the [local workstation](../workstation/overview.md) and [provisioning lifecycle](../provisioning/overview.md)

## In this section

- [Environment injection](environment-injection.md): per-context environment variables and the shell hook
- [Trusted folders](trusted-folders.md): the trust gate that guards environment injection

## Reference

- [`windsor init`](https://www.windsorcli.dev/reference/cli/commands/init), [`windsor set`](https://www.windsorcli.dev/reference/cli/commands/set), [`windsor get`](https://www.windsorcli.dev/reference/cli/commands/get)
- [Contexts reference](https://www.windsorcli.dev/reference/cli/contexts): on-disk layout of `contexts/`, including what lives in each context's `values.yaml`
- [Configuration reference](https://www.windsorcli.dev/reference/cli/configuration): full schema for values a context accepts
