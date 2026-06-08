---
title: Explain
description: Trace blueprint values back to their sources to debug composition.
---

A Windsor blueprint is composed from many places: facets, context values, deferred Terraform outputs, inline expressions. When a value isn't what you expected, [`windsor explain <path>`](/reference/cli/commands/explain) tells you where it actually came from and which other contributions were overridden.

## The show → find → explain flow

`explain` is most useful as the second step of a debugging loop. Start by rendering the blueprint, find the value that surprises you, then trace it.

**1. Render the blueprint for the current context:**

```bash
windsor show blueprint
```

```yaml
terraform:
- name: cluster
  path: cluster/azure-aks
  dependsOn:
  - network
  inputs:
    cert_manager_dns_zone_ids: []
    create_cert_manager_identity: false
    external_dns_dns_zone_ids: <deferred>
    pools: {}
    private_subnet_ids: <deferred>
```

**2. Spot a value worth investigating.** `external_dns_dns_zone_ids` is `<deferred>` — that's expected if its source hasn't been applied yet, but you want to see *what* is being deferred and where it came from.

**3. Trace it:**

```bash
windsor explain terraform.cluster.inputs.external_dns_dns_zone_ids
```

```text
terraform.cluster.inputs.external_dns_dns_zone_ids (deferred)
  /…/contexts/_template/facets/platform-azure.yaml:107
    gateway.access
    dns.private_domain
      /…/contexts/_template/facets/platform-base.yaml:185
      dns.private_domain (cycle)
      dns.domain
        /…/contexts/_template/facets/platform-base.yaml:183
        dns.domain (cycle)
        dev
      dev
    dns.public_domain
      /…/contexts/_template/facets/platform-base.yaml:184
      dns.public_domain (cycle)
```

Reading the output:

- The first line is the path and its resolved status (here, `(deferred)`).
- The next indent level lists each contributor with `file:line`. In this case the value is built from a single facet at `platform-azure.yaml:107`.
- Inside that contribution, the expression references `gateway.access`, `dns.private_domain`, `dns.public_domain`. Each is expanded under it with its own `file:line` and any literal fallbacks (here, `dev`).
- Markers like `(cycle)` annotate edges that would form a loop — Windsor breaks the cycle and uses the literal fallback.

The same flow works for any path:

```bash
# A Flux substitution looks wrong
windsor explain kustomize.dns.substitutions.external_domain

# A list field — see every contribution that built it
windsor explain kustomize.policy-resources.components
```

```text
kustomize.policy-resources.components
  [0] kyverno/resource-limits-requests
  /…/contexts/_template/facets/platform-base.yaml:379
  [1] kyverno/require-image-digest
  /…/contexts/_template/facets/platform-base.yaml:380
```

Each list element gets its own contributor line, so you can see which facet appended what.

## When to reach for it

- "Why is this Terraform input set to that value?"
- "Which facet wins when two define the same substitution?"
- "Is this expression deferred, or actually empty?"
- "Why isn't my override taking effect?"

## Status markers

Resolved values may include a marker after the path or inside an expression chain:

- `(deferred)` — depends on a Terraform output that hasn't been applied yet. Apply the dependency (or let `windsor apply` walk the graph) and re-run.
- `(empty)` — the chain resolved, but the result is an empty string.
- `(not set)` — the referenced facet config was never provided.
- `(cycle)` — the expression chain forms a cycle. Windsor breaks the cycle and uses the literal fallback at that node.

## Reference

- [`windsor explain`](/reference/cli/commands/explain) — full path syntax, output markers, and examples.
- [`windsor show`](/reference/cli/commands/show) — render the blueprint, kustomization, or values for the current context — the natural starting point for a debugging session.
- [Facets](/blueprints/facets) — where most contributions originate.
