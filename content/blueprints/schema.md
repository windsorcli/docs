---
title: Schema
description: How a blueprint's schema.yaml validates each context's values, fills in defaults, and marks a value as sensitive.
---

A context's [values](overview.md#values-and-schema) decide which facets apply. A misspelled key such as `platfrom: aws` reads as nil in every [expression](expressions.md#member-access-is-always-optional), so without a check it would change the blueprint without a warning. The template's `contexts/_template/schema.yaml` is that check. Windsor validates each context's `values.yaml` against it and fills in a default for each key the context leaves out.

## Overview

The schema file must be valid JSON Schema, and Windsor implements a subset of JSON Schema Draft 2020-12. Every context that uses the template validates against the same schema, so all of them accept the same keys with the same meaning.

## Example

This listing trims the `core` [`schema.yaml`](https://github.com/windsorcli/core/blob/main/contexts/_template/schema.yaml) to two of its properties, `platform` and `topology`.

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

`production` sets `platform: aws`, which is in the `enum`, so it passes. A context that sets `platform: openstack` fails validation, and a context that sets no platform gets `none` from `default:`. `topology` has no `default:`, so it stays unset unless the context sets it. The top-level `additionalProperties: false` rejects any key the schema doesn't declare, which catches `platfrom: aws`.

## Usage

When Windsor loads a blueprint, it applies `_template/schema.yaml`, if the template has one, to the context's values before it evaluates any [facet](facets.md). [The _template folder](templates.md#composition-order) gives the full composition order.

## Marking a property sensitive

A property with `sensitive: true` has its value redacted wherever Windsor displays configuration. `core` marks the Hetzner Cloud API token this way.

```yaml
properties:
  hetzner:
    properties:
      token:
        type: string
        sensitive: true
```

Windsor shows the value as `<sensitive>` in [`windsor show values`](https://www.windsorcli.dev/reference/cli/commands/show-values). The flag doesn't change how Windsor stores or resolves the value, only how it shows the value back to the operator.

Windsor rejects, at composition time, a `substitutions` or `substitute` value that is a bare `${path}` reference to a sensitive property, because substitutions render into a plaintext ConfigMap. To land the value as a Kubernetes Secret, use a `flux:` system's `secrets:` block, which [Facets — Kubernetes Secrets](facets.md#kubernetes-secrets) describes.
