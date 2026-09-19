---
title: Facets
description: Conditional blueprint composition from configuration.
---

**Facets** are YAML files under `contexts/_template/facets/` that add or modify blueprint content based on configuration (for example, platform, feature flags). They let one template support multiple environments and options without duplicating the base blueprint.

## Overview

- Loaded from `_template/facets/*.yaml` and `_template/facets/**/*.yaml`.
- Ordered by ordinal (ascending), then by name.
- Each facet has a `when` expression; when it evaluates to true, that facet's Terraform components, Kustomizations, Flux systems, and [config blocks](#config-blocks) are merged.

## Example

```yaml
kind: Facet
apiVersion: blueprints.windsorcli.dev/v1alpha1
metadata:
  name: aws-facet
  description: AWS-specific infrastructure
when: platform == 'aws'
terraform:
  - path: network/vpc
    source: core
    inputs:
      cidr: ${network.cidr_block ?? "10.0.0.0/16"}
    strategy: merge
```

When `platform` is `aws`, the VPC Terraform component from `core` is included. Expressions can reference [schema](schema.md) properties and `terraform_output()` for cross-component values.

## Config blocks

A `config:` entry computes a named value from expressions and exposes it at scope root, alongside `values.yaml` properties like `cluster.driver` — so `terraform:` inputs, `kustomize:` substitutions, and other facets' own expressions can reference it the same way. This is different from a `values.yaml` default: a schema default is only visible where the property itself is read, but a config block's value is visible to *every* facet that composes after it, including facets from a different blueprint source. That cross-facet visibility is the reason this mechanism exists — see [Schema](schema.md) for `values.yaml` properties and their defaults.

```yaml
config:
  - name: pki_effective
    value:
      issuer_component: public-issuer/selfsigned
  - name: pki_effective
    when: (dns.public_domain ?? '') != ''
    value:
      issuer_component: public-issuer/acme/route53
  - name: pki_effective
    when: gateway.access == 'private' && (dns.private_domain ?? '') != ''
    value:
      issuer_component: ""
```

Three blocks share the name `pki_effective` here, each contributing under its own `when:`. A scalar or list value is read as `${pki_effective}`; a map value like this one is read key by key — `${pki_effective.issuer_component}` — from a `terraform:` input, a `kustomize:` substitution, or another config block's own `value:`.

### Merge precedence

Within one facet, later entries win: the last block whose `when:` matches is the one that applies, same as the `pki_effective` example above. Across facets, the facet that composes later wins — the same rule `terraform:` and `kustomize:` entries already follow (see [Ordinals](#ordinals) below). `strategy: replace` or `strategy: remove` change that behavior for one block, but the default (`merge`) is right for almost every case.

### Evaluation order

A block's `value:` can reference another block. Windsor works out the right order automatically, so you don't need to declare blocks in dependency order yourself.

## Ordinals

If a facet does not set `ordinal`, it is derived from the filename:

| Pattern | Ordinal |
| --- | --- |
| `config-*` | 100 |
| `platform-*-base` / `provider-*-base` (filename contains `-base`) | 199 |
| `platform-*` / `provider-*` | 200 |
| `option-*` / `options-*` | 300 |
| `addon-*` / `addons-*` | 400 |
| anything else | 0 |

Higher ordinal means higher precedence when merging (addons override platform-base for same-name entries). A filename matching none of these patterns gets ordinal 0 — lower than even `config-*` — so it's worth naming facets to match one of these prefixes rather than relying on the fallback.

## File resolution

Paths in facets (for example, `jsonnet()`, `file()`) are relative to the facet file under `_template/`. A facet at `_template/facets/aws.yaml` can reference `_template/facets/config.jsonnet` or `../configs/config.jsonnet`.

## Kubernetes Secrets

A facet can wire a `sensitive: true` [schema](schema.md#marking-a-property-sensitive) value into a `flux:` system's `secrets:` block to land it as a Kubernetes Secret in a Flux-managed namespace. See [Flux systems](flux-systems.md) for the install/resources tiers, merge strategy, and `globalDependency`.

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

- [Expressions](expressions.md) — the `when:` / `${...}` language and Windsor's added functions
- [Blueprint templates](templates.md) — How the _template folder and composition order work.
- [Testing](testing.md) — Testing facet conditions and expected components.
- [Schema — Marking a property sensitive](schema.md#marking-a-property-sensitive) — the `sensitive: true` flag this section's `data:` values must carry
