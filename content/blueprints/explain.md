---
title: Debug
description: Trace blueprint values back to their sources to debug composition.
---

A value in the composed blueprint can come from a facet, a context's values, a deferred Terraform output, or an inline expression, and several of them can set the same path. When a value isn't what you expected, reading the facets by hand means following every expression that might have touched it. [`windsor explain <path>`](https://www.windsorcli.dev/reference/cli/commands/explain) shows where the value came from and which other contributions it overrode.

## The show → find → explain flow

`explain` is most useful as the second step of a debugging loop. You render the blueprint, find the unexpected value, and then trace it.

First, render the blueprint for the current context. This excerpt of the output shows the `cluster` entry for an Azure context.

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

Next, pick a value worth investigating. `external_dns_dns_zone_ids` is `<deferred>`. That's expected if its source hasn't been applied yet, but you want to see *what* is being deferred and where it came from.

Then trace it. `windsor explain` takes the value's path in the composed blueprint and prints the chain that produced it.

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

The trace reads from the top down.

- The first line is the path and its resolved status, here `(deferred)`.
- The next indent level lists each contributor with `file:line`. In this case a single facet at `platform-azure.yaml:107` builds the value.
- Inside that contribution, the expression references `gateway.access`, `dns.private_domain`, and `dns.public_domain`. Each is expanded under it with its own `file:line` and any literal fallbacks, here `dev`.
- A marker such as `(cycle)` annotates an edge that would form a loop. Windsor breaks the cycle and uses the literal fallback.

The same flow works for any path, including a Flux substitution or a list field.

```bash
# A Flux substitution looks wrong
windsor explain kustomize.dns.substitutions.external_domain

# A list field — see every contribution that built it
windsor explain kustomize.policy-resources.components
```

For a list field, the trace gives each element its own contributor line, so you can see which facet appended what.

```text
kustomize.policy-resources.components
  [0] kyverno/resource-limits-requests
  /…/contexts/_template/facets/platform-base.yaml:379
  [1] kyverno/require-image-digest
  /…/contexts/_template/facets/platform-base.yaml:380
```

## When to use it

`explain` answers questions like these.

- "Why is this Terraform input set to that value?"
- "Which facet wins when two define the same substitution?"
- "Is this expression deferred, or empty?"
- "Why isn't my override taking effect?"

## Status markers

A resolved value can carry one of these markers after its path or inside an expression chain.

- `(deferred)`: depends on a Terraform output that hasn't been applied yet. Apply the dependency, or let [`windsor apply`](https://www.windsorcli.dev/reference/cli/commands/apply) walk the graph, and re-run.
- `(empty)`: the chain resolved, but the result is an empty string.
- `(not set)`: the referenced facet config was never provided.
- `(cycle)`: the expression chain forms a cycle. Windsor breaks the cycle and uses the literal fallback at that node.

## Reference

- [`windsor explain`](https://www.windsorcli.dev/reference/cli/commands/explain): full path syntax, output markers, and examples
- [`windsor show`](https://www.windsorcli.dev/reference/cli/commands/show): render the blueprint, a kustomization, or the values for the current context
- [Inspecting](inspecting.md): [`windsor plan`](https://www.windsorcli.dev/reference/cli/commands/plan), `show`, and `explain` together
- [Facets](facets.md): where most contributions come from
