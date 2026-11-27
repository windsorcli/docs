---
title: Welcome to the Windsor docs
description: What Windsor is, and how to find your way through this guide.
---

<!-- ai: rough draft -->

## What Windsor is

Windsor is an infrastructure-as-code authoring and provisioning tool. It drives Terraform and Kustomize to stand up a complete infrastructure stack on a cloud platform, a hypervisor, bare metal, or your own workstation.

Windsor is a single CLI written in Go, released under the MPL 2.0 license, with builds for Linux, macOS, and Windows. It needs no Windsor service or account, so it runs the same way on your workstation and in a CI/CD pipeline.

You describe a stack as a [blueprint](blueprints/overview.md): the Terraform modules and Kustomize manifests that make it up, and the order Windsor applies them in. Windsor pushes a blueprint to any OCI registry as an artifact, so other projects can pull it by tag. A blueprint plays the role of a Helm chart for a whole stack instead of one application.

Most projects start from the [`core`](https://www.windsorcli.dev/catalog/core) blueprint rather than an empty one. A new context lists `core` as its source and adds its own values and components on top. The [`manager`](https://www.windsorcli.dev/catalog/manager) blueprint is built the same way, layered on `core`. The [blueprint catalog](https://www.windsorcli.dev/catalog) documents both.

You can also use Windsor only to manage environments. A project holds one or more [contexts](contexts/overview.md), such as `local` and `production`, and Windsor [injects](contexts/environment-injection.md) each context's variables into your shell, the way [direnv](https://github.com/direnv/direnv) or [mise](https://mise.jdx.dev) do. When you switch contexts, `KUBECONFIG`, the cloud profile, and the Terraform variables move to the new context.

## How to use this guide

The guide has three parts. Read it front to back, or start with the part you need.

- **Orientation.** [Getting started](https://www.windsorcli.dev/cli/installation) installs the CLI and runs a [first project](getting-started/first-project.md) on your workstation. [Contexts](contexts/overview.md) and [Secrets](secrets/overview.md) cover environments and credentials, which every later chapter uses.
- **Provisioning.** The [lifecycle](provisioning/overview.md) covers the commands every target shares, the [state backend](provisioning/state-backend.md), [upgrading](provisioning/upgrade.md), and [tearing down](provisioning/destroy.md). The chapters after it stand a stack up on your [workstation](workstation/overview.md), a [hypervisor](virtual/hyperv.md), or a [cloud](cloud/aws.md). [CI/CD](ci-cd/github-actions.md) runs the same commands from a pipeline.
- **Composition.** Add your own [Terraform](components/terraform.md) and [Kustomize](components/kustomize.md) components. [Blueprints](blueprints/overview.md) covers authoring a reusable stack with [facets](blueprints/facets.md) and [sharing](blueprints/sharing.md) it through public and private OCI registries.
