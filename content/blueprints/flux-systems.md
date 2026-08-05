---
title: Flux systems
description: How flux entries compose into multi-tier Flux Kustomizations, distinct from the kustomize 1:1 passthrough.
---

A `flux:` entry in `blueprint.yaml` is a **system**: a named functional layer that compiles to an install Kustomization plus one or more resources Kustomizations. This is different from `kustomize:`, which is a 1:1 passthrough where each entry maps to exactly one Kustomization; see [Kustomize](kustomize.md). Facets typically contribute `flux:` entries rather than `kustomize:` ones, since a system's controller and the custom resources it admits usually need separate reconciliation tiers.

```yaml
flux:
  - name: policy
    globalDependency: true
    install:
      components:
        - kyverno
      timeout: 30m
    resources:
      - components:
          - kyverno/resource-limits-requests
        timeout: 5m
```

## Install and resources tiers

`install` is the controller/operator tier (at most one). `resources` is an array of custom-resource tier variants, all sharing the same path. Both reuse the same Kustomization shape as `kustomize:` entries: `components`, `substitutions`, `timeout`, `interval`, `patches`, and the rest.

A system named `policy` with both tiers compiles to `policy-install` and `policy-resources`; `resources` reconciles after `install` automatically, since `install` is a precondition for the custom resources its own controller admits. Naming and path are derived: `path` defaults to the system's `name`, and tiers reconcile from `<path>/install` and `<path>/resources`. A system with more than one resources variant (multiple `when`-gated entries in the `resources` array) suffixes each as `<name>-resources-<variant>`.

If every component in a tier evaluates to empty (all conditional entries fail their `when`), Windsor emits no Kustomization for that tier rather than an empty one.

## Resources-only systems

A system can skip `install` entirely and declare only `resources`, when there's no controller to install and no CRDs to gate on, just resources to reconcile onto an existing installation. `gitops` in the [core](https://github.com/windsorcli/core) blueprint is one: it's resources-only, since it reconciles onto Flux itself rather than installing a controller.

```yaml
flux:
  - name: gitops
    path: gitops
    when: (gitops.mode ?? 'push') == 'push'
    dependsOn:
      - "${gateway.enabled == true ? 'gateway-resources' : ''}"
    resources:
      - components:
          - webhook
        timeout: 5m
```

A `dependsOn` naming a controller-less system resolves to that system's resources tier automatically, since there's no install tier to attach to.

## Merging across facets

Multiple `flux:` entries sharing the same `name` merge into one system, in the order facets compose. `core`'s `platform-base` facet declares a `gitops` system with the webhook resources shown above; a later facet can add a second `- name: gitops` entry (same `path`) to layer in more resources, for example a web UI route, without redeclaring the whole system.

`strategy` controls how same-named entries combine across facets: `merge` (the default) deep-merges install/resources/secrets; `replace` discards the existing system for one activated later; `remove` drops it. `core`'s `addon-observability` facet uses `replace` to swap `platform-base`'s `telemetry` system's Elasticsearch-backed log stack in for the default fluent-bit one when a driver switch requires a different component set rather than an additive merge.

`ordinal` controls precedence when systems merge: a higher ordinal wins. Facets get a default ordinal from their filename pattern (`platform-*` is 200, `addon-*` is 400); a system can override it with its own `ordinal`. See [Facets — Ordinals](facets.md#ordinals).

## globalDependency

A system with `globalDependency: true` inverts the usual dependency direction: instead of every consumer naming it in `dependsOn`, it declares itself a cluster-wide precondition once. Every kustomization and system outside its own dependency closure is wired to wait on its terminal tier (resources if present, otherwise install). `core`'s `policy` system uses this so admission policies are enforcing before any workload lands, without every other system repeating `dependsOn: [policy-resources]`.

## Kubernetes Secrets

A `flux:` system can also declare a `secrets:` block to land a `sensitive: true` schema value as a Kubernetes Secret in its namespace. See [Facets — Kubernetes Secrets](facets.md#kubernetes-secrets).

## See also

- [Kustomize](kustomize.md) — the `kustomize:` 1:1 passthrough, and how substitutions and patches work for either layer
- [Facets](facets.md) — how facets contribute `flux:` entries, ordinals, and Kubernetes Secrets
- [Blueprint reference](https://www.windsorcli.dev/reference/cli/blueprint) — full `flux[]` schema
