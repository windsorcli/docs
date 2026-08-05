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

When `provider` is `aws`, the VPC Terraform component from `core` is included. Expressions can reference [schema](schema.md) properties and `terraform_output()` for cross-component values.

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

## Kubernetes Secrets

A facet can wire a `sensitive: true` [schema](schema.md#marking-a-property-sensitive) value into a `flux:` system's `secrets:` block to land it as a Kubernetes Secret in a Flux-managed namespace. This is separate from `kustomize:`, the 1:1 Kustomization passthrough covered in [Kustomize](kustomize.md); `flux:` entries are system-level and compile to an install Kustomization plus one or more resources Kustomizations.

```yaml
flux:
  - name: telemetry
    secrets:
      alertmanager-notification-slack:
        data:
          url: ${telemetry.alerts.slack.webhook_url}
```

`data` maps Secret keys to resolved expressions, never plaintext literals; the referenced `telemetry.alerts.slack.webhook_url` property must itself be `sensitive: true`. Windsor materializes an Opaque Secret by default, ordered after the owning system's install Kustomization. A `.dockerconfigjson` key (or `docker-username` plus `docker-password`) materializes as `kubernetes.io/dockerconfigjson` instead, for use as an `imagePullSecret`.

An optional `namespaces:` list targets more than one namespace; empty means auto-resolve the single namespace the owning kustomization creates. Removing an entry prunes the corresponding cluster Secret on the next apply; changing an entry's resolved data rolls workloads that reference it. See the [Blueprint reference](https://www.windsorcli.dev/reference/cli/blueprint) for the full `flux[].secrets{}` schema.

## See also

- [Blueprint templates](templates.md) — How the _template folder and composition order work.
- [Blueprint testing](testing.md) — Testing facet conditions and expected components.
- [Securing secrets](../deployment/securing-secrets.md) — marking schema values sensitive
