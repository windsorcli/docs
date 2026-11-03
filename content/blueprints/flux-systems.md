---
title: Flux systems
description: How flux entries compose into multi-tier Flux Kustomizations, distinct from the kustomize 1:1 passthrough.
---

Kyverno enforces admission policies, but a policy is a custom resource that only Kyverno's controller can admit. If the controller and the policies land in one Kustomization, the policies fail to apply until the controller and its CRDs exist. A [*Flux system*](overview.md#terraform-components-and-flux-systems) splits them into tiers that reconcile in order. This entry from `core`'s `platform-base.yaml`, trimmed to two components per tier, declares the `policy` system.

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
          - kyverno
          - kyverno/resource-limits-requests
        timeout: 8m
```

Windsor compiles this entry into two Flux Kustomizations. `policy-install` deploys the Kyverno controller, and `policy-resources` applies the policies after `policy-install` is ready. `globalDependency: true` makes every other workload wait for the policies, as [globalDependency](#globaldependency) describes.

A `kustomize:` entry works differently: each entry maps to exactly one Kustomization, as [Kustomize](../components/kustomize.md) describes. Facets usually contribute `flux:` entries rather than `kustomize:` ones, because a system's controller and the custom resources it admits must reconcile in separate tiers. Every facet in `core` uses `flux:` entries only.

## Install and resources tiers

`install` is the controller or operator tier, and a system has at most one. `resources` is an array of custom-resource tier variants, all sharing the same path. Both tiers take the same fields as a `kustomize:` entry, including `components`, `substitutions`, `timeout`, `interval`, and `patches`.

A system named `policy` with both tiers compiles to `policy-install` and `policy-resources`. Windsor makes `resources` reconcile after `install`, because `install` is a precondition for the custom resources its own controller admits. Windsor also derives the paths. `path` defaults to the system's `name`, and the tiers reconcile from `<path>/install` and `<path>/resources`. A system with more than one resources variant, which means more than one `when`-gated entry in the `resources` array, suffixes each as `<name>-resources-<variant>`.

If every component in a tier evaluates to empty, because every conditional entry fails its `when`, Windsor emits no Kustomization for that tier rather than an empty one.

## Resources-only systems

A system can skip `install` and declare only `resources` when there's no controller to install and no CRDs to gate on, only resources to reconcile onto an existing installation. The `gitops` system in [`core`](https://github.com/windsorcli/core) is one. It reconciles a webhook onto Flux itself, which Terraform has already installed. This entry from `platform-base.yaml` is trimmed to its first component.

```yaml
flux:
  - name: gitops
    path: gitops
    when: (gitops.mode ?? 'push') == 'push'
    dependsOn:
      - "${gateway.enabled == true && gateway_effective.internal == true ? 'gateway-resources-internal' : ''}"
    resources:
      - components:
          - webhook
        timeout: 5m
```

A `dependsOn` that references a system with no install tier resolves to that system's resources tier, since there's no install tier to attach to.

## Merging across facets

Multiple `flux:` entries that share a `name` merge into one system, in the order facets compose. `core`'s `platform-base` facet declares the `gitops` system with the webhook entry shown in [Resources-only systems](#resources-only-systems). A second `- name: gitops` entry in the same facet, with the same `path`, adds the Flux web UI route when `gitops.web_ui` is on, without redeclaring the whole system.

`strategy` controls how entries with the same name combine across facets. The default, `merge`, deep-merges `install`, `resources`, and `secrets`. `replace` discards the existing system in favor of one activated later, and `remove` drops it. When `observability.logs_driver` is `elasticsearch`, `core`'s `addon-observability` facet uses `replace` to swap `platform-base`'s `telemetry` system, which ships logs with fluent-bit, for one that ships them with the `filebeat` component.

`ordinal` controls precedence when systems merge, and a higher ordinal wins. Facets get a default ordinal from their filename pattern (`platform-*` is 200, `addon-*` is 400), and a system can override it with its own `ordinal`. [Facets — Ordinals](facets.md#ordinals) lists the patterns.

## globalDependency

A system with `globalDependency: true` inverts the usual dependency direction. Rather than every consumer listing it in `dependsOn`, the system declares itself a cluster-wide precondition once. Windsor makes every kustomization and system outside the system's own dependency closure wait on its terminal tier, which is the resources tier if it has one and the install tier otherwise. `core`'s `policy` system uses this so that admission policies enforce before any workload lands, without every other system repeating `dependsOn: [policy-resources]`.

## Kubernetes Secrets

A `flux:` system can also declare a `secrets:` block to land a resolved value, such as a `sensitive: true` schema property, as a Kubernetes Secret in its namespace. [Facets — Kubernetes Secrets](facets.md#kubernetes-secrets) covers the block.

## See also

- [Kustomize](../components/kustomize.md): the one-to-one `kustomize:` entry, and how substitutions and patches work for either kind
- [Facets](facets.md): how facets contribute `flux:` entries, ordinals, and Kubernetes Secrets
- [Blueprint reference](https://www.windsorcli.dev/reference/cli/blueprint): the full `flux[]` schema
