---
title: Facets
description: Conditional blueprint composition from configuration.
---

**Facets** are YAML files under `contexts/_template/facets/` that add or modify blueprint content based on configuration (for example, provider, feature flags). They let one template support multiple environments and options without duplicating the base blueprint.

## Overview

- Loaded from `_template/facets/*.yaml` and `_template/facets/**/*.yaml`.
- Ordered by ordinal (ascending), then by name.
- Each facet has a `when` expression; when it evaluates to true, that facet's Terraform/Kustomize entries are merged.

## Example

```yaml
kind: Facet
apiVersion: blueprints.windsorcli.dev/v1alpha1
metadata:
  name: aws-facet
  description: AWS-specific infrastructure
when: provider == 'aws'
terraform:
  - path: network/vpc
    source: core
    inputs:
      cidr: ${network.cidr_block ?? "10.0.0.0/16"}
    strategy: merge
```

When `provider` is `aws`, the VPC Terraform component from `core` is included. Expressions can reference [schema](/blueprints/schema) properties and `terraform_output()` for cross-component values.

## Ordinals

If a facet does not set `ordinal`, it is derived from the filename:

| Pattern | Ordinal |
| --- | --- |
| `config-*` | 100 |
| `provider-base` / `platform-base` | 199 |
| `provider-*` / `platform-*` | 200 |
| `options-*` / `option` | 300 |
| `addon` / `addons` | 400 |

Higher ordinal means higher precedence when merging (addons override provider-base for same-name entries).

## File resolution

Paths in facets (for example, `jsonnet()`, `file()`) are relative to the facet file under `_template/`. A facet at `_template/facets/aws.yaml` can reference `_template/facets/config.jsonnet` or `../configs/config.jsonnet`.

## See also

- [Blueprint templates](/blueprints/templates) — How the _template folder and composition order work.
- [Blueprint testing](/blueprints/testing) — Testing facet conditions and expected components.
