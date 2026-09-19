---
title: Welcome to the Windsor docs!
description: What Windsor is, and how to find your way through this guide.
---

## What Windsor is

Windsor is an infrastructure provisioning tool. It drives Terraform and Kustomize against a Kubernetes cluster, and manages the context, credentials, and environment variables each command needs along the way.

You can use it two ways. Add your own [Terraform](components/terraform.md) modules and [Kustomizations](components/kustomize.md) directly to one context, on top of a blueprint you consume. Or author a blueprint: a template that composes the same kind of components across every context in a project, with conditional fragments (facets) and a schema for the values each context sets — see [Blueprints](blueprints/overview.md). Both produce the same `windsor apply`; only how you got there differs.

Most projects start from the default [`core`](https://github.com/windsorcli/core) blueprint, which bootstraps the infrastructure, a configured Kubernetes cluster, and a set of common cloud services. `core` is open to extend: add components on top of it, or write your own blueprint that consumes it.

Windsor currently provisions AWS, Azure, Hetzner, two hypervisors (Hyper-V, vSphere), a local workstation VM, and bare metal you already have. A blueprint's Kustomize layer runs the same way regardless of target; only the Terraform layer underneath changes.

## How to use this guide

- **New to Windsor?** Start at [Getting started](getting-started/first-project.md) — install the CLI and run a local stack.
- **Already have Terraform and Kubernetes manifests, and want Windsor to run them for one context?** Go to [Components](components/terraform.md).
- **Need the same infrastructure across contexts, or want to publish it for other projects to consume?** [Blueprints](blueprints/overview.md) covers the template model.
- **Deploying to a specific target?** [Local](workstation/overview.md), [Virtual](virtual/hyperv.md), [Cloud](cloud/aws.md), and [Metal](metal/overview.md) each cover their own setup.
- **Already running — moving to a newer blueprint version, tearing it down, or want CI to apply changes instead of a person?** [Upgrade](maintenance/upgrade.md), [Destroy](maintenance/destroy.md), and [CI/CD](ci-cd/github-actions.md) cover the ongoing side of running it.
- **Looking for a specific flag or YAML key?** [Reference](https://www.windsorcli.dev/reference/cli/configuration) covers the CLI and the `core` blueprint in full.

## Chapters

- [Getting started](getting-started/first-project.md) — install the CLI and run your first stack
- [Contexts](contexts/overview.md) — environments and per-context configuration
- [Secrets](secrets/sops.md) — SOPS and 1Password for context secrets
- [Local](workstation/overview.md), [Virtual](virtual/hyperv.md), [Cloud](cloud/aws.md), [Metal](metal/overview.md) — provisioning a context on each target
- [Components](components/terraform.md) — adding your own Terraform and Kustomize to a consumed blueprint
- [Blueprints](blueprints/overview.md) — the full authoring model, for building something reusable
- [Upgrade](maintenance/upgrade.md) — moving a context to a newer blueprint version
- [Destroy](maintenance/destroy.md) — safety behaviors and locking on teardown
- [CI/CD](ci-cd/github-actions.md) — running Windsor from a pipeline instead of a shell
- [Reference](https://www.windsorcli.dev/reference/cli/configuration) — in-depth references for the CLI and `core` blueprint
