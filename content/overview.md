---
title: Welcome to the Windsor docs!
description: Documentation index for Windsor CLI.
---

Windsor is an infrastructure provisioning tool. A blueprint author can codify 100% of a distributed compute system and its requirements into a single versioned package. Consumers of blueprints can deploy them to the compute platform of their choosing.

Currently, Windsor supports AWS, Azure, virtualized platforms (Hyper-V), and bare metal (no-os). Windsor abstracts the underlying infrastructure cleanly from the application layer, using standard tools from within and around the Cloud Native computing ecosystem. The workloads you deploy on top run the same way on every supported target.

The goal is to enable anyone to operate secure, private, and reliable compute infrastructure on their own terms. Blueprints should be repeatable, testable, and offer a clean authorship contract for delivering high-fidelity self-hosted services from minimum prerequisites.

Blueprint authorship is key to this project's success. Most of the current documentation covers the `core` blueprint. This provides the infrastructure bootstrapping, a properly configured Kubernetes cluster, and essential cloud services. More blueprints are coming. If you want to author one, read on, get in touch, and extend `core`.

- [`cli/`](/cli/installation) - key concepts that are useful when running `windsor` commands
- [`workstation/`](/workstation/overview) - how-tos for running a blueprint locally in 'dev' mode
- [`deployment/`](/deployment/aws) - how-tos for bootstrapping your infrastructure on cloud (AWS, Azure), virtualized platforms (Hyper-V), or bare metal you own
- [`reference/`](/reference/cli/configuration) - in-depth references for the CLI and core blueprint
