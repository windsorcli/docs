---
title: Facets
description: How a facet adds components to a blueprint when a context's values match, and how config blocks share computed values between facets.
---

The `core` template has one facet per platform, from AWS to vSphere, but each context runs on only one of them. `production` on AWS needs a VPC and an EKS cluster, and `local` on Docker needs neither. A [*facet*](overview.md#facets) is a file in the template that adds components only when its `when:` condition is true for the current context. This page covers how Windsor loads, orders, and merges facets.

## Overview

Windsor loads every file that matches `_template/facets/*.yaml` or `_template/facets/**/*.yaml` and sorts the facets by [ordinal](#ordinals), lowest first, then by name. It evaluates each facet's `when:` expression against the context's values. For each facet whose condition is true, Windsor merges its Terraform components, Kustomizations, Flux systems, and [config blocks](#config-blocks) into the blueprint.

## Example

[`platform-aws.yaml`](https://github.com/windsorcli/core/blob/main/contexts/_template/facets/platform-aws.yaml) in `core` adds the AWS network and cluster. This listing trims it to the `network` and `cluster` entries, with two inputs each.

```yaml
kind: Facet
apiVersion: blueprints.windsorcli.dev/v1alpha1
metadata:
  name: aws
when: platform == 'aws'
terraform:
  - name: network
    path: network/aws-vpc
    inputs:
      cidr_block: ${network.cidr_block}
      domain_name: ${dns.private_domain ?? ""}
  - name: cluster
    path: cluster/aws-eks
    dependsOn:
      - network
    inputs:
      vpc_id: ${terraform_output('network', 'vpc_id')}
      private_subnet_ids: ${terraform_output('network', 'private_subnet_ids')}
```

For `production`, `platform` is `aws`, so the top-level `when:` is true and both entries join its blueprint. `${network.cidr_block}` reads the CIDR from `production`'s values. When a context sets no `dns.private_domain`, the `??` operator supplies an empty string instead. The `cluster` entry reads two outputs of `network` through `terraform_output()`, and its `dependsOn` makes Windsor apply `network` first.

An expression in a facet can read any value that the [schema](schema.md) declares, any config block from a facet that composes before it, and another Terraform component's outputs through `terraform_output()`. [Expressions](expressions.md) lists the operators and functions.

## Config blocks

Some settings depend on other settings. On AWS, the public ClusterIssuer depends on DNS: with a public zone, cert-manager can use ACME through Route 53, and without one it uses a self-signed issuer. A *config block* computes a value like this once, under a name, from expressions. These two blocks from `platform-aws.yaml` compute `pki_effective`.

```yaml
config:
  - name: pki_effective
    value:
      issuer_component: public-issuer/selfsigned
  - name: pki_effective
    when: >-
      dns_zone_effective.enabled == true && (pki.public_issuer ?? 'acme') != 'selfsigned'
    value:
      issuer_component: public-issuer/acme/route53
```

The first block has no `when:`, so it always applies and sets the self-signed issuer. The second applies when the context has a public DNS zone and `pki.public_issuer` is not `selfsigned`. It comes later, so its `issuer_component` wins. A scalar or list value is read as `${pki_effective}`. A map value like this one is read key by key, as `${pki_effective.issuer_component}`, from a `terraform:` input, a `kustomize:` substitution, or another config block's `value:`.

Windsor exposes a config block's value at the scope root, alongside `values.yaml` properties such as `cluster.driver`, so every expression reads both the same way. A schema default works differently: it is visible only where the property itself is read. A config block's value is visible to every facet that composes after it, including facets from a different blueprint source, and that visibility across facets is the reason config blocks exist. [Schema](schema.md) covers `values.yaml` properties and their defaults.

### Merge precedence

Within one facet, matching blocks with the same name apply in order. Map values deep-merge, and for a scalar or list the last block whose `when:` matches wins. Across facets, the higher [ordinal](#ordinals) takes precedence, which is the same rule that `terraform:` and `kustomize:` entries follow, and the default `merge` strategy deep-merges maps the same way. `strategy: replace` or `strategy: remove` changes that for one block. `merge` suits almost every case.

### Evaluation order

A block's `value:` can reference another block. Windsor orders the blocks by those references, so a file can declare a block before the block it reads.

## Ordinals

A facet can set `ordinal` itself. When it doesn't, Windsor derives the ordinal from the filename, as this table shows.

| Pattern | Ordinal |
| --- | --- |
| `config-*` | 100 |
| `platform-*-base` / `provider-*-base` (filename contains `-base`) | 199 |
| `platform-*` / `provider-*` | 200 |
| `option-*` / `options-*` | 300 |
| `addon-*` / `addons-*` | 400 |
| anything else | 0 |

Higher ordinal means higher precedence when merging, so an addon overrides a platform base for entries with the same name. A filename matching none of these patterns gets ordinal 0, lower than even `config-*`. Name facets to match one of these prefixes rather than relying on the fallback.

## File resolution

Paths in facets, for example in `jsonnet()` and `file()`, are relative to the facet file under `_template/`. A facet at `_template/facets/aws.yaml` can reference `_template/facets/config.jsonnet` or `../configs/config.jsonnet`.

## Kubernetes Secrets

A facet can wire a `sensitive: true` [schema](schema.md#marking-a-property-sensitive) value into the `secrets:` block of a `flux:` system, and Windsor lands it as a Kubernetes Secret in a Flux-managed namespace. This entry from `addon-observability.yaml` in `core`, trimmed of its `when:`, turns Grafana's OIDC client secret into a Secret.

```yaml
flux:
  - name: observability
    secrets:
      grafana-oidc-client:
        data:
          clientSecret: ${observability.grafana.client_secret}
```

`data` maps Secret keys to `${...}` expressions, here the `observability.grafana.client_secret` property, and Windsor rejects a plaintext literal. Mark the property `sensitive: true` in the schema anyway, so that `windsor show values` redacts it and `substitutions:` never carries it. By default Windsor materializes an Opaque Secret, ordered after the owning system's install Kustomization. A `.dockerconfigjson` key, or `docker-username` plus `docker-password`, materializes as `kubernetes.io/dockerconfigjson` instead, for use as an `imagePullSecret`.

An optional `namespaces:` list targets more than one namespace. Without it, Windsor uses the single namespace that the owning kustomization creates. Removing an entry prunes its Secret from the cluster on the next apply, and changing an entry's resolved data rolls the workloads that reference it. [Flux systems](flux-systems.md) covers the install and resources tiers, the merge strategy, and `globalDependency`, and the [blueprint reference](https://www.windsorcli.dev/reference/cli/blueprint) has the full `flux[].secrets{}` schema.

## See also

- [Expressions](expressions.md): the `when:` and `${...}` language, and the functions Windsor adds
- [The _template folder](templates.md): the template's files and the composition order
- [Testing](testing.md): testing facet conditions and the components they add
- [Schema — Marking a property sensitive](schema.md#marking-a-property-sensitive): the `sensitive: true` flag that redacts a value and keeps it out of `substitutions:`
- [Secrets](../secrets/overview.md): how Windsor resolves secret references
