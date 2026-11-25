---
title: Overview
description: A context is a named environment (local, staging, production) with its own blueprint, values, and credentials, and Windsor tracks which one is active.
---

One project usually deploys to more than one place. You run a cluster on your laptop while you work, and the same platform runs on AWS for real traffic. The two must not share a kubeconfig, a cloud profile, or Terraform state, or a command meant for your laptop lands on production. A *context* is a named environment inside a project, such as `local` or `production`. It has its own blueprint, its own values, and its own credentials. Windsor tracks one *active context*, and every command acts on it.

The examples in this section follow one project with two contexts. `local` runs on Docker Desktop on your workstation. `production` runs on AWS in `us-east-1`. Both use the [`core`](https://github.com/windsorcli/core) blueprint.

## Create a context

In a git repository, `windsor init` creates the project and its first context:

```bash
windsor init
```

```text
Initialization successful
```

On the first run, `init` writes `windsor.yaml` in the current directory and creates `contexts/local/`. It also adds the project to your [trusted folders](trusted-folders.md). With no context name, `init` uses the active context, and `local` when none is set. `init` refuses to run outside a git repository.

To add `production`, give `init` a name and a platform. AWS needs a region, so pass it with `--set`:

```bash
windsor init production --platform aws --set aws.region=us-east-1
```

`init` creates `contexts/production/` and makes `production` the active context. Without the region, `init` stops and lists the missing value:

```text
error: the following required values are not set in values.yaml:

  - aws.region
```

`init` switches the active context and writes `contexts/production/values.yaml` before it checks the values. After the error, `production` is still the active context, with a partial `values.yaml`. Add the region to that file, or rerun `init` with `--set`.

## What a context holds

Windsor keeps each context's files in `contexts/<context>/` under the project root. This listing shows the project after `init` for both contexts and a first `windsor up` in `local`.

```text
windsor.yaml                     version: v1alpha2
contexts/
├── local/
│   ├── blueprint.yaml           the context's blueprint
│   ├── values.yaml              the context's values
│   ├── .gitignore               keeps credentials and kubeconfig out of commits
│   ├── .kube/config             kubeconfig, written by windsor up
│   └── .talos/config            talosconfig, written by windsor up
└── production/
    ├── blueprint.yaml
    └── values.yaml
.windsor/                        generated files; git-ignored
├── context                      the active context name
└── contexts/local/              Terraform module shims and workstation config
```

`values.yaml` holds the context's *values*, the settings the blueprint reads. `init` writes the ones it can work out. For `production` they are the platform, the region, and a state backend:

```yaml
# contexts/production/values.yaml
id: w6hcydi7
platform: aws
terraform:
  backend:
    type: s3
    auto_prefix: true
aws:
  region: us-east-1
```

You add other files as you need them: `terraform/<module>.tfvars` for your own Terraform modules, `patches/` for Kustomize patches, `.env` and `secrets.enc.yaml` for secrets. The [contexts reference](https://www.windsorcli.dev/reference/cli/contexts) lists every file.

## Switch contexts

[`windsor set context`](https://www.windsorcli.dev/reference/cli/commands/set-context) changes the active context, and [`windsor get context`](https://www.windsorcli.dev/reference/cli/commands/get-context) prints it:

```bash
windsor set context local
windsor get context
```

```text
local
```

`set context` writes the name to `.windsor/context`. When that file is absent, Windsor reads `WINDSOR_CONTEXT` from the environment, then falls back to `local`. The context must already exist:

```text
error: context "staging" not found
hint: Run windsor init staging to create it.
```

[`windsor get contexts`](https://www.windsorcli.dev/reference/cli/commands/get-contexts) lists every context and marks the active one:

```text
NAME        PROVIDER  BACKEND  CURRENT
local       docker    local    *
production  aws       s3
```

After a switch, the shell hook moves `KUBECONFIG`, the cloud profile, and the context's other variables to the new context at your next prompt. See [Environment injection](environment-injection.md).

## Context ID

A context's name can change. Its *id* does not. `init` writes a random `id` into `values.yaml`, such as `w6hcydi7`: a `w` and 7 lowercase letters and digits. The `core` Terraform modules use the `id` in the names of the resources they create, such as the S3 state bucket `terraform-state-<id>`.

To choose the `id`, set it before the first deploy:

```yaml
# contexts/production/values.yaml
id: web-production
```

An `id` is a DNS label. It has 1 to 63 characters and starts with a lowercase letter. It contains only lowercase letters, digits, and hyphens, never two hyphens in a row, and does not end with a hyphen. `init` and `up` reject any other value:

```text
error: Context id "Web_Production" must start with a lowercase letter (a-z).
hint: Change id in values.yaml or in the --set flag, or remove it so that windsor generates one.
```

Many cloud names allow fewer than 63 characters. When the `id` is too long for a name, the `core` module shortens it and appends the first 6 hex characters of its SHA-256 hash, so the name stays unique. The README of each [`core` Terraform module](https://github.com/windsorcli/core/tree/main/terraform) lists its limits in a "Context id" section.

## Workstation vs. deployed contexts

A *workstation context* runs its cluster on your machine, and Windsor starts and stops the container runtime or VM it runs in. `init` makes a context named `local`, or starting with `local-`, a workstation context and records `dev: true` in its `values.yaml`. Every other context is *deployed*: it targets a cloud, a hypervisor, or bare metal, and Windsor provisions that infrastructure.

|                 | Workstation                                                              | Deployed                                                                           |
| --------------- | ------------------------------------------------------------------------ | ---------------------------------------------------------------------------------- |
| Cluster runs on | Your machine                                                             | A cloud, hypervisor, or bare metal                                                 |
| First run       | [`windsor up`](https://www.windsorcli.dev/reference/cli/commands/up)     | [`windsor bootstrap`](https://www.windsorcli.dev/reference/cli/commands/bootstrap) |
| Tear down       | [`windsor down`](https://www.windsorcli.dev/reference/cli/commands/down) | [`windsor destroy`](https://www.windsorcli.dev/reference/cli/commands/destroy)     |

See the [workstation overview](../workstation/overview.md) and the [provisioning lifecycle](../provisioning/overview.md).

## In this section

- [Environment injection](environment-injection.md): per-context environment variables and the shell hook
- [Trusted folders](trusted-folders.md): the trust gate that guards environment injection

## Reference

- [`windsor init`](https://www.windsorcli.dev/reference/cli/commands/init), [`windsor set context`](https://www.windsorcli.dev/reference/cli/commands/set-context), [`windsor get context`](https://www.windsorcli.dev/reference/cli/commands/get-context)
- [Contexts reference](https://www.windsorcli.dev/reference/cli/contexts): on-disk layout of `contexts/`
- [Configuration reference](https://www.windsorcli.dev/reference/cli/configuration): every value a context accepts
