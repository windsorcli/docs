---
title: Overview
description: What's in a blueprint, and how to write one.
---

[Components](../components/terraform.md) puts Terraform modules and Kustomizations directly in one context's `blueprint.yaml`. That works as long as one context is all you have. A blueprint turns the same components into a template, shared by every context instead of hand-copied into each one. It lists:

- The Terraform components that provision infrastructure
- The Kustomizations that run on a Kubernetes cluster
- The configuration values the operator can set
- The conditional fragments (facets) that activate based on those values

Either section can be empty, so a blueprint can be a full Kubernetes platform or just a Terraform stack.

Windsor reads a blueprint, fills in the values for the current context, and deploys the platform to your chosen target. Most projects start with the default [`core`](https://github.com/windsorcli/core) blueprint and customize a few values.

A blueprint lives in `contexts/_template/`. The directory always contains a `blueprint.yaml` — the same `terraform:`/`kustomize:` shape as [Components](../components/terraform.md), now written once and inherited by every context. The other files in `_template/` are optional.

| File | Purpose |
|---|---|
| `blueprint.yaml` | Terraform components and Kustomizations the platform installs |
| `schema.yaml` | JSON Schema for the configuration values the blueprint accepts |
| `metadata.yaml` | Name, version, and CLI version requirement |
| `facets/` | Conditional fragments activated by context values |

A blueprint can also be published as an OCI artifact and reused by other projects. The default `core` blueprint is published at `oci://ghcr.io/windsorcli/core:v0.8.0`.

Per-context customizations live in `contexts/<name>/`. Files there override or extend what `_template/` defines for that one context, so most contexts share their blueprint and differ only where they need to.

## Where to next

- [Directory layout](templates.md)
- [Schema dialect](schema.md)
- [Facets and conditional fragments](facets.md)
- [Flux systems](flux-systems.md)
- [Registries](sharing.md)
- [Testing](testing.md)
- [Inspecting](inspecting.md)
