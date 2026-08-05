---
title: Inspecting
description: Inspect a context's composition with windsor plan, show, and explain before and after apply.
---

Three commands inspect what Windsor will do and what it composed, without changing anything. `windsor plan` previews infrastructure changes, `windsor show` renders the composed blueprint, and `windsor explain` traces a single value back to its source.

## Preview changes with `windsor plan`

`windsor plan` previews changes without applying them. With no argument it prints a summary across all components; with a name it streams the full plan for one component:

```bash
windsor plan                    # summary across all components
windsor plan terraform cluster  # full plan for one component
```

Output is sorted destructive-first. Add `--summary` for the compact table, `--json` for machine-readable output in CI, or `--no-color` to disable color. See [Lifecycle](../contexts/lifecycle.md) for where `plan` fits in the apply flow.

## Render the composition with `windsor show`

`windsor show` renders what a blueprint composes to for the current context, reading the composition without touching the cluster:

```bash
windsor show blueprint              # the fully composed blueprint
windsor show values                 # effective context values
windsor show kustomization <name>   # a rendered Flux Kustomization
```

Run it after editing facets or values to confirm the result before you apply.

## Trace a value with `windsor explain`

A composed value can come from several places: a facet, a context file, a deferred Terraform output, or an inline expression. When one isn't what you expected, `windsor explain <path>` traces it back through the composition: where it was set, what expression produced it, and which other contributions it overrode.

```bash
windsor explain terraform.cluster.inputs.cluster_endpoint
```

The output names each contributing facet or context file with its `file:line`, expands the expression chain, and marks values that are deferred or form a cycle. [Explain](explain.md) covers reading the output in full, including every status marker.

## Reference

- [`windsor plan`](https://www.windsorcli.dev/reference/cli/commands/plan), [`windsor show`](https://www.windsorcli.dev/reference/cli/commands/show), [`windsor explain`](https://www.windsorcli.dev/reference/cli/commands/explain)
- [Explain](explain.md) — reading an explain trace in detail
- [Lifecycle](../contexts/lifecycle.md) — where `plan` fits in the apply flow
