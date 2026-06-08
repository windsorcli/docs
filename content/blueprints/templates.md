---
title: The _template folder
description: Shared blueprint template structure and composition order.
---

The `contexts/_template/` directory is the base every context in the project inherits from. It pairs a [`blueprint.yaml`](#blueprintyaml) with optional [`schema.yaml`](#schemayaml), [`metadata.yaml`](#metadatayaml), and a [`facets/`](/blueprints/facets) directory of conditional fragments. When you initialize a context, Windsor loads `_template/`, evaluates facets against the context's values, and merges the result into a context-specific blueprint.

Run `windsor show blueprint` to see the result for the current context.

## Directory structure

```text
contexts/
└── _template/
    ├── blueprint.yaml      # Base blueprint (required)
    ├── schema.yaml         # JSON Schema for config (optional)
    ├── metadata.yaml       # Name, version, CLI version constraint (optional)
    └── facets/             # Facet definitions (optional)
        ├── config-cluster.yaml
        ├── platform-base.yaml
        ├── platform-aws.yaml
        ├── option-observability.yaml
        ├── addon-bookinfo.yaml
        └── ...
```

Files at any depth under `facets/` are loaded.

## blueprint.yaml

The base blueprint. Defines repository, sources, and any unconditional Terraform components and Kustomizations that all contexts share. Always loaded and merged in full.

```yaml
kind: Blueprint
apiVersion: blueprints.windsorcli.dev/v1alpha1
metadata:
  name: base
  description: Base blueprint for all contexts
sources:
  - name: core
    url: oci://ghcr.io/windsorcli/core:v0.6.0
terraform:
  - source: core
    path: cluster/talos
kustomize:
  - name: ingress
    path: ingress/base
    source: core
```

Context-specific `blueprint.yaml` files (for example, `contexts/local/blueprint.yaml`) can extend or override this base.

## schema.yaml

JSON Schema that validates the user's `values.yaml` and supplies defaults for missing keys.

```yaml
$schema: https://json-schema.org/draft/2020-12/schema
type: object
properties:
  platform:
    type: string
    default: "none"
    enum: ["none", "metal", "docker", "aws", "azure", "gcp"]
  observability:
    type: object
    properties:
      enabled:
        type: boolean
        default: false
    additionalProperties: false
additionalProperties: false
```

Use `$schema: https://json-schema.org/draft/2020-12/schema`. The earlier `https://windsorcli.dev/draft/2026-02/schema` dialect was removed in v0.9.0; a schema still declaring it fails validation with a migration hint. See [Schema](/blueprints/schema).

## metadata.yaml

Blueprint metadata, including the CLI version constraint:

```yaml
name: my-blueprint
version: 1.0.0
cliVersion: ">=0.9.0"
```

Constraint forms: `">=0.9.0"`, `"~0.9.0"`, `">=0.9.0 <0.10.0"`. Always quote — unquoted `>` and `<` are YAML control characters. If the running CLI version doesn't satisfy the constraint, blueprint loading fails with a clear error.

## facets/

A facet is a YAML file under `_template/facets/` that contributes to the composed blueprint when its `when` expression is true. Each facet can carry config blocks, conditional Terraform components, conditional Kustomizations, and common substitutions. Facets are evaluated by ordinal (ascending), then by name.

See [Facets](/blueprints/facets) for the full authoring model — `when` expressions, ordinals, merge strategies, config blocks, and the `terraform_output()` substitution helper.

## Composition order

When Windsor builds the final blueprint:

1. **OCI sources with `deploy: true`** — components from these sources are merged. Sources with `deploy: false` are index-only — their components aren't merged but components elsewhere can reference them via `source: <name>`. Non-OCI sources (Git URLs) are always index-only.
2. **Base template** — `_template/blueprint.yaml` merges in full.
3. **Facets** — processed in ordinal order, with strategies and `when` expressions applied.
4. **User blueprint** — `contexts/<name>/blueprint.yaml` overrides without filtering. Components from earlier layers remain unless this layer sets `destroy: false` or omits them by name when the merge strategy is `replace`. See [Facets — merge strategies](/blueprints/facets).

Only OCI sources can have their components merged; the `deploy` flag only applies to OCI sources and defaults to `true` when omitted.

## See also

- [Schema](/blueprints/schema) — Validation and defaults.
- [Facets](/blueprints/facets) — Conditional composition and expression authoring.
- [Sharing blueprints](/blueprints/sharing) — Pushing and bundling.
- [Blueprint testing](/blueprints/testing) — Static tests for blueprint composition.
