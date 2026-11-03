---
title: The _template folder
description: The files in a project's contexts/_template folder, what each one does, and how they compose into a context's blueprint.
---

A project with a `local` and a `production` context declares what both share in one place, `contexts/_template/`. The folder pairs a [`blueprint.yaml`](#blueprintyaml) with an optional [`schema.yaml`](#schemayaml), [`metadata.yaml`](#metadatayaml), and a [`facets/`](facets.md) directory of conditional fragments. When you initialize a context, Windsor loads `_template/`, evaluates the facets against the context's values, and merges the result into a context-specific blueprint. This page covers each file in turn.

Run [`windsor show blueprint`](https://www.windsorcli.dev/reference/cli/commands/show-blueprint) to see the result for the current context.

## Directory structure

This tree shows the files a template can hold, with a few of the facet files from `core`.

```text
contexts/
└── _template/
    ├── blueprint.yaml      # Base blueprint (required)
    ├── schema.yaml         # JSON Schema for config (optional)
    ├── metadata.yaml       # Name, version, CLI version constraint (optional)
    ├── facets/             # Facet definitions (optional)
    │   ├── config-talos.yaml
    │   ├── platform-base.yaml
    │   ├── platform-aws.yaml
    │   ├── option-gateway.yaml
    │   ├── addon-observability.yaml
    │   └── ...
    └── tests/              # windsor test cases (optional)
```

Windsor loads files at any depth under `facets/`. [Testing](testing.md) covers the files in `tests/`.

## blueprint.yaml

`blueprint.yaml` is the base blueprint. It declares the sources and any unconditional Terraform components and Kustomizations that all contexts share, and Windsor always loads and merges it in full. This base blueprint pulls `core` from its registry and deploys the Talos cluster and the OpenEBS storage driver from it.

```yaml
kind: Blueprint
apiVersion: blueprints.windsorcli.dev/v1alpha1
metadata:
  name: base
  description: Base blueprint for all contexts
sources:
  - name: core
    url: oci://ghcr.io/windsorcli/core:v0.9.0
terraform:
  - source: core
    path: cluster/talos
kustomize:
  - name: csi
    path: csi/install
    source: core
    components:
      - openebs
```

A context's own `blueprint.yaml`, such as `contexts/local/blueprint.yaml`, can extend or override this base.

### The `backend` field

The top-level `backend:` field references the Terraform component that creates the state backend. On `up`, Windsor applies that component, and every Terraform component declared before it, using local state, then moves their state into the backend. On `destroy`, those components are removed last. [State backend](../provisioning/state-backend.md#bootstrap) covers the full flow.

A blueprint that builds a Talos cluster on Docker and keeps its state there references the component that creates the state namespace.

```yaml
backend: backend
terraform:
  - name: compute
    path: compute/docker
  - name: cluster
    path: cluster/talos
  - name: backend
    path: backend/kubernetes
    dependsOn:
      - cluster
    inputs:
      namespace: system-terraform
```

Declaration order decides what goes with the backend component, not `dependsOn`. Anything listed before it is applied on local state too, so keep those components at the top of the list. A facet can set `backend:` as well, and when two facets set it, the one with the higher [ordinal](facets.md#ordinals) wins. Windsor rejects a `backend:` that references a component that doesn't exist.

You only need `backend:` when the blueprint creates its own state store: a cloud bucket, or the cluster and its state namespace for the `kubernetes` backend. With the `kubernetes` backend and no `backend:` set, `windsor up` stops before the cluster exists and asks you to add one.

## schema.yaml

`schema.yaml` is a JSON Schema that validates each context's `values.yaml` and supplies defaults for missing keys. This listing trims `core`'s schema to two properties.

```yaml
$schema: https://json-schema.org/draft/2020-12/schema
type: object
properties:
  platform:
    type: string
    enum: [none, aws, azure, gcp, hetzner, incus, metal, docker, hyperv, vsphere, proxmox]
    default: none
  topology:
    type: string
    enum: [single-node, multi-node, ha]
additionalProperties: false
```

Use `$schema: https://json-schema.org/draft/2020-12/schema`. Windsor removed the earlier `https://windsorcli.dev/draft/2026-02/schema` dialect in v0.9.0, and a schema that still declares it fails validation with a migration hint. [Schema](schema.md) covers validation and defaults.

## metadata.yaml

`metadata.yaml` holds the blueprint's name and version and the CLI versions it supports.

```yaml
name: my-blueprint
version: 1.0.0
cliVersion: ">=0.9.0"
```

`cliVersion` takes a version range, such as `">=0.9.0"`, `"~0.9.0"`, or `">=0.9.0 <0.10.0"`. Always quote it, because unquoted `>` and `<` are YAML control characters. If the running CLI version doesn't satisfy the range, Windsor fails to load the blueprint with a clear error.

## facets/

A facet is a YAML file under `_template/facets/` that contributes to the composed blueprint when its `when` expression is true. Each facet can carry config blocks, conditional Terraform components, conditional Kustomizations, and common substitutions. Windsor evaluates facets by ordinal, lowest first, then by name.

[Facets](facets.md) covers the full authoring model: `when` expressions, ordinals, merge strategies, config blocks, and the `terraform_output()` substitution helper.

## Composition order

[Composition workflow](../composition/workflow.md) covers the merge order (OCI sources, base template, facets, user blueprint) and how CRD layers sequence ahead of the stack.

## See also

- [Composition workflow](../composition/workflow.md): merge order and CRD layers
- [Schema](schema.md): validation and defaults
- [Facets](facets.md): conditional composition and expression authoring
- [Expressions](expressions.md): the `when:` and `${...}` language, and the functions Windsor adds
- [Registries](sharing.md): pushing and bundling
- [Testing](testing.md): static tests for blueprint composition
