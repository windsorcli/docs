---
title: Welcome to the Windsor docs!
description: Documentation index for Windsor CLI.
---

Windsor is an infrastructure provisioning tool. A blueprint author can codify 100% of a distributed compute system and its requirements into a single versioned package. Consumers of blueprints can deploy them to the compute platform of their choosing.

Currently, Windsor supports AWS, Azure, virtualized platforms (Hyper-V), and bare metal (no-os). Windsor abstracts the underlying infrastructure cleanly from the application layer, using standard tools from within and around the Cloud Native computing ecosystem. The workloads you deploy on top run the same way on every supported target.

The goal is to enable anyone to operate secure, private, and reliable compute infrastructure on their own terms. Blueprints should be repeatable, testable, and offer a clean authorship contract for delivering high-fidelity self-hosted services from minimum prerequisites.

Blueprint authorship is key to this project's success. Most of the documentation covers the `core` blueprint, which provides the infrastructure bootstrapping, a properly configured Kubernetes cluster, and essential cloud services. `core` is the primary blueprint today, and the authorship contract is open — to write your own, read on, get in touch, and extend `core`.

- [Getting started](getting-started/first-project.md) — install the CLI and run your first local stack
- [Contexts](contexts/overview.md) — environments, lifecycle, and per-context configuration
- [Blueprints](blueprints/overview.md) — how a stack is composed, customized, and shared
- [Workstation](workstation/overview.md) — running a blueprint locally in dev mode
- [Deployment](deployment/overview.md) — bootstrapping infrastructure on AWS, Azure, or bare metal you own
- [Troubleshooting](troubleshooting/overview.md) — common failure modes and their fixes
- [Reference](https://www.windsorcli.dev/reference/cli/configuration) — in-depth references for the CLI and `core` blueprint
