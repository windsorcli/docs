---
title: Blueprints
description: What's in a blueprint, and how to write one.
---

A blueprint is the recipe for what Windsor installs. It lists the Terraform components that provision infrastructure, the Kustomize stacks that run on a Kubernetes cluster, the configuration values the operator can set, and the conditional fragments (facets) that activate based on those values. Either section can be empty, so a blueprint can be a full Kubernetes platform or just a Terraform stack.

Windsor reads a blueprint, fills in the values for the current context, and brings the platform up on whatever target you point it at. Most projects start with the default [`core`](https://github.com/windsorcli/core) blueprint and customize a few values.

A blueprint lives in `contexts/_template/`. The directory always contains a `blueprint.yaml`, which lists the Terraform components and Kustomize stacks the platform installs. The other files in `_template/` are optional.

| File | Purpose |
|---|---|
| `blueprint.yaml` | Terraform components and Kustomize stacks the platform installs |
| `schema.yaml` | JSON Schema for the configuration values the blueprint accepts |
| `metadata.yaml` | Name, version, and CLI version requirement |
| `facets/` | Conditional fragments activated by context values |

A blueprint can also be published as an OCI artifact and reused by other projects. The default `core` blueprint is published at `oci://ghcr.io/windsorcli/core:v0.6.0`.

Per-context customizations live in `contexts/<name>/`. Files there override or extend what `_template/` defines for that one context, so most contexts share their blueprint and differ only where they need to.

## Where to next

- [Directory layout](/blueprints/templates)
- [Schema dialect](/blueprints/schema)
- [Facets and conditional fragments](/blueprints/facets)
- [Sharing via OCI](/blueprints/sharing)
- [Testing](/blueprints/testing)
