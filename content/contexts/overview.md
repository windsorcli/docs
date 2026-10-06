---
title: Overview
description: A context is a named environment (local, staging, production) with its own blueprint, values, and credentials, and Windsor tracks which one is active.
---

A context is a named environment, such as `local`, `staging`, or `production`. It has its own blueprint, values, credentials, and kubeconfig, and Windsor tracks which context is active. Commands act on the active context, and [environment injection](environment-injection.md) points `kubectl`, `terraform`, and the cloud CLIs at it.

Contexts usually map to a stage (`development`, `staging`, `production`), a slice of infrastructure (`admin`, `web`, `observability`), or both, like `web-staging`. Several contexts can share the same infrastructure code while their credentials, endpoints, and input values stay separate.

Windsor keeps a context's files under `contexts/<context-name>/` in the project root.

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
├── context                      the active context name; Windsor assumes `local` when it is absent
└── contexts/local/              generated Terraform module shims, workstation config, and the stack lock
```

## Create a context

In a git repository, `windsor init` creates the project: a `windsor.yaml` at the root on the first run, and a `local` context with a starter `blueprint.yaml` and `values.yaml`:

```bash
windsor init
```

To add another context, give it a name and a platform. AWS needs a region, so pass one with `--set`:

```bash
windsor init production --platform aws --set aws.region=us-east-1
```

This creates `contexts/production/` with its own `blueprint.yaml` and `values.yaml`, and makes it the active context. Without a region, `init` stops and names the missing value.

## Switch contexts

Set the active context, then check it:

```bash
windsor set context <context-name>
windsor get context
```

`windsor set context` writes the context name to `.windsor/context` and sets `WINDSOR_CONTEXT` for the current process. The context must exist already. Otherwise the command fails and tells you to run `windsor init <name>`. By your next prompt, the shell hook has refreshed the per-context environment, including kubeconfig and the cloud profile. See [Environment injection](environment-injection.md).

## Workstation vs. deployed contexts

A workstation context, named `local` or starting with `local-`, runs a Kubernetes cluster on your machine. Windsor starts and stops the VM or container runtime it runs in. Every other context, like `staging` or `production`, is deployed. It targets a cloud, a hypervisor, or bare metal, and Windsor provisions the infrastructure directly.

|                 | Workstation                                                                                          | Deployed                                                                           |
| --------------- | ---------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------- |
| Cluster runs on | Your machine                                                                                         | A cloud, hypervisor, or bare metal                                                 |
| First run       | [`windsor up`](https://www.windsorcli.dev/reference/cli/commands/up)                                 | [`windsor bootstrap`](https://www.windsorcli.dev/reference/cli/commands/bootstrap) |
| Tear down       | [`windsor down`](https://www.windsorcli.dev/reference/cli/commands/down)                             | [`windsor destroy`](https://www.windsorcli.dev/reference/cli/commands/destroy)     |

See the [workstation overview](../workstation/overview.md) and the [provisioning lifecycle](../provisioning/overview.md).

## In this section

- [Environment injection](environment-injection.md): per-context environment variables and the shell hook
- [Trusted folders](trusted-folders.md): the trust gate that guards environment injection

## Reference

- [`windsor init`](https://www.windsorcli.dev/reference/cli/commands/init), [`windsor set`](https://www.windsorcli.dev/reference/cli/commands/set), [`windsor get`](https://www.windsorcli.dev/reference/cli/commands/get)
- [Contexts reference](https://www.windsorcli.dev/reference/cli/contexts): on-disk layout of `contexts/`, including what lives in each context's `values.yaml`
- [Configuration reference](https://www.windsorcli.dev/reference/cli/configuration): full schema for values a context accepts
