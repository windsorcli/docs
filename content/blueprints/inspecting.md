---
title: Inspecting
description: Inspect a context's composition with windsor plan, show, and explain before and after apply.
---

Before you apply a facet or values change to `production`, you want to know which resources it replaces, what the composed blueprint looks like, and where a surprising value came from. Three commands answer those questions without changing anything. `windsor plan` previews infrastructure changes, `windsor show` renders the composed blueprint, and `windsor explain` traces a single value back to its source.

## Preview changes with `windsor plan`

`windsor plan` previews changes without applying them. With no argument it prints a summary across all components, and with a component it streams the full plan for that one.

```bash
windsor plan                    # summary across all components
windsor plan terraform cluster  # full plan for one component
```

Windsor sorts the output with destructive changes first. Add `--summary` for the compact table, `--json` for machine-readable output in CI, or `--no-color` to turn off color. [Lifecycle](../provisioning/overview.md) shows where `plan` fits in the apply flow.

## Render the composition with `windsor show`

`windsor show` renders what the blueprint composes to for the current context. It reads the composition and doesn't touch the cluster.

```bash
windsor show blueprint              # the fully composed blueprint
windsor show values                 # effective context values
windsor show kustomization <name>   # a rendered Flux Kustomization
```

Run it after you edit facets or values to confirm the result before you apply.

## Trace a value with `windsor explain`

A composed value can come from a facet, a context file, a deferred Terraform output, or an inline expression, and several of them can set the same path. When a value isn't what you expected, `windsor explain <path>` traces it back through the composition. It shows where the value was set, which expression produced it, and which other contributions it overrode.

```bash
windsor explain terraform.cluster.inputs.cluster_endpoint
```

The output lists each contributing facet or context file with its `file:line`, expands the expression chain, and marks values that are deferred or form a cycle. [Debug](explain.md) covers reading the output in full, including every status marker.

## Reference

- [`windsor plan`](https://www.windsorcli.dev/reference/cli/commands/plan), [`windsor show`](https://www.windsorcli.dev/reference/cli/commands/show), [`windsor explain`](https://www.windsorcli.dev/reference/cli/commands/explain)
- [Debug](explain.md): reading an explain trace in detail
- [Lifecycle](../provisioning/overview.md): where `plan` fits in the apply flow
