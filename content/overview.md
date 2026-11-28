---
title: Welcome to the Windsor docs
description: What Windsor is, and how to find your way through this guide.
---

## What Windsor is

Windsor is a framework for building and distributing self-hosted infrastructure. Leveraging open-source, industry-standard tooling, you can quickly launch complete stacks to a variety of compute platforms. A stack, or [blueprint](blueprints/overview.md), can deploy directly to mini-PCs, single-board machines (Raspberry Pi), datacenters, or public clouds with minimal prerequisites.

As a complete SDK, Windsor makes it possible to run a blueprint on your local machine using Docker or native virtualization. A CLI written in Go runs on Windows, macOS, and Linux. No accounts or sign-ups are involved other than a public cloud account. If you build directly on your own hardware, no third-party services are required at all.

Blueprints are defined using conventional [Terraform](components/terraform.md) and [Kustomize](components/kustomize.md). A [core](https://www.windsorcli.dev/catalog/core) blueprint is provided with most of the basic adapters, connectors, and system services required to operate a standard runtime on top of your chosen compute platform. Applications you write on top of these blueprints may likewise be deployed to any compute platform supported by Windsor.

You can build your own blueprint on top of [core](https://www.windsorcli.dev/catalog/core). Any blueprint you build can in turn be distributed to others as an [OCI artifact](blueprints/sharing.md). Blueprints are deployed using a single command, such as:

```bash
windsor bootstrap production --platform aws --set aws.region=us-east-1 \
  --blueprint oci://ghcr.io/your-org/your-blueprint:v0.1.0
```

## How to use this guide

The guide has been written in the style of a textbook. You can read it through end to end, or dive into specific reference material. If you're using an AI coding agent, you can point it at these pages and ask it to set up your project using Windsor.

The guide has three parts.

- **Orientation.** [Getting started](https://www.windsorcli.dev/cli/installation) installs the CLI and runs a [first project](getting-started/first-project.md) on your workstation. [Contexts](contexts/overview.md) and [Secrets](secrets/overview.md) cover environments and credentials, which later chapters use.
- **Provisioning.** The [lifecycle](provisioning/overview.md) chapter takes a context from `init` to teardown. The chapters after it deploy a stack to a [workstation](workstation/overview.md), a [hypervisor](virtual/hyperv.md), or a [cloud](cloud/aws.md). [CI/CD](ci-cd/github-actions.md) runs the same commands from a pipeline.
- **Composition.** [Components](components/terraform.md) adds your own Terraform and [Kustomize](components/kustomize.md) to a context. [Blueprints](blueprints/overview.md) covers authoring a reusable stack with [facets](blueprints/facets.md) and sharing it through OCI registries.

Flags and schemas are documented in the [CLI reference](https://www.windsorcli.dev/reference/cli/commands/up) and the [core catalog](https://www.windsorcli.dev/catalog/core/values).
