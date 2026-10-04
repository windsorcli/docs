---
title: Welcome to the Windsor docs
description: What Windsor is, and how to find your way through this guide.
---

## What Windsor is

Windsor is an infrastructure-as-code authoring and provisioning tool. It drives Terraform and Kustomize to launch complete infrastructure stacks against major cloud platforms, hypervisors, or bare metal.

As a CLI, Windsor does not depend on a service, and is distributed with an open-source MPL 2.0 license. It's built in Go and runs on Linux, macOS, and Windows. It can be run from your local workstation or in a
CI/CD environment.

Stacks are built and distributed as [blueprints](blueprints/overview.md), a portable artifact that bundles as an OCI image. Blueprints are similar to Helm charts, but for the entire stack, not just single applications.

Rather than build your blueprint from scratch, you will tend to build on top of the existing [core](https://www.windsorcli.dev/catalog/core) blueprint, documented in the [blueprint catalog](https://www.windsorcli.dev/catalog). A [manager](https://www.windsorcli.dev/catalog/manager) blueprint is also available, which itself inherits from core.

You may also use Windsor only as an environment manager. It helps you organize your project and environments as [contexts](contexts/overview.md). It performs [environment injection](contexts/environment-injection.md) similar to tools like [direnv](https://github.com/direnv/direnv) or [mise](https://mise.jdx.dev).
As you switch contexts, your environment is dynamically reconfigured, pointing your tools at the
correct auth files and backends.

## How to use this guide

The guide is divided into four parts. Read it front to back, or jump to the part you need.

- **Orientation.** [Getting started](getting-started/first-project.md) installs the CLI and runs a local stack. [Contexts](contexts/overview.md) and [Secrets](secrets/overview.md) cover environments and credentials, which are
prerequisites for all the chapters that follow.
- **Provisioning.** Stands a stack up on a target of your choice. Targets your [workstation](workstation/overview.md), a [hypervisor](virtual/hyperv.md), or a [cloud](cloud/aws.md). The [lifecycle](provisioning/workflow.md) covers the commands those targets share.
- **Composition.** Add your own components written in [Terraform](components/terraform.md) and [Kustomize](components/kustomize.md). [Blueprints](blueprints/overview.md) covers authoring reusable stacks with [facets](blueprints/facets.md). Distribute your blueprint as an [OCI artifact](blueprints/sharing.md) to public and private registries.
- **Operations.** Running it once it's up: [upgrading](maintenance/upgrade.md), [tearing down](maintenance/destroy.md), and [CI/CD](ci-cd/github-actions.md).
