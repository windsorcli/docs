---
title: Schema
description: JSON Schema for blueprint configuration validation.
---

The `contexts/_template/schema.yaml` file defines the expected structure and default values for configuration. Windsor uses it to validate and fill in values from `windsor.yaml` and `values.yaml`.

## Overview

- **Validation** — Ensures configuration matches the schema.
- **Defaults** — Missing keys get default values.
- **Consistency** — Same shape across contexts.

The schema file must be valid JSON Schema. Windsor implements a subset of **JSON Schema Draft 2020-12**.

## Example

```yaml
$schema: https://json-schema.org/draft/2020-12/schema
type: object
properties:
  provider:
    type: string
    default: "none"
    enum: ["none", "metal", "docker", "aws", "azure", "gcp"]
  observability:
    type: object
    properties:
      enabled:
        type: boolean
        default: false
      backend:
        type: string
        default: "quickwit"
        enum: ["quickwit", "loki", "elasticsearch"]
    additionalProperties: false
additionalProperties: false
```

## Usage

When a blueprint is loaded, the schema from `_template/schema.yaml` (if present) is applied to the context's configuration before [facets](/blueprints/facets) are evaluated. See [Blueprint templates](/blueprints/templates) for the full composition order.
