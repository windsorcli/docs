---
title: Kustomize
description: How Windsor composes Flux Kustomizations from blueprints, with substitutions, patches, and destroy-only hooks.
---

The kustomize layer is the second half of a blueprint, applied after Terraform. Each entry under `kustomize:` in `blueprint.yaml` becomes a Flux [`Kustomization`](https://fluxcd.io/flux/components/kustomize/kustomizations/) resource that points at a path in a blueprint source. Flux then reconciles the resources at that path onto the cluster. This is a 1:1 passthrough: for the multi-tier `flux:` system entries facets typically contribute instead, see [Flux systems](flux-systems.md).

`windsor apply` (or `windsor up` for workstation contexts) installs every kustomization in dependency order. `windsor destroy` removes them all in reverse-topological order. Use `windsor apply kustomize <name>` or `windsor destroy kustomize <name>` to target a single kustomization.

## Folder layout

See [Components — Kustomize](../components/kustomize.md) for the `kustomize:` entry shape — local `path:` vs. a remote `source:`. A local entry's files sit under `kustomize/` in the project root; per-context patches sit under `contexts/<name>/patches/`:

```text
contexts/
└── local/
    ├── blueprint.yaml
    └── patches/
        └── my-app/
            └── increase-replicas.yaml
kustomize/
└── my-app/
    ├── prometheus/
    │   ├── kustomization.yaml
    │   └── service-monitor.yaml
    ├── kustomization.yaml
    ├── deployment.yaml
    └── service.yaml
```

`my-app` here is the local app from that page's own example — a Prometheus [Kustomize component](https://kubectl.docs.kubernetes.io/guides/config_management/components/), referenced without a `source:`. For the full Kustomization schema (every field, type, and default) see the [blueprint reference](https://www.windsorcli.dev/reference/cli/blueprint).

## Add-on components

An add-on's own README (`kustomize/<name>` in a blueprint's repo) breaks it down into named **components** — for example Identity's `keycloak-operator`, `keycloak`, and `oidc-federation`. That's a different, Windsor-specific meaning from the Kustomize `components:` field above.

Each named component is a real, distinct resource inside the add-on — a HelmRelease, a Job, an HTTPRoute — gated by its own condition: a config flag, another add-on being enabled, a platform choice. A component's condition decides whether it exists in your context at all, not how it's patched.

The Catalog's own guides stick to what you configure at the `values.yaml` layer; for the full component breakdown, read the add-on's README directly — see [Identity](https://github.com/windsorcli/core/tree/main/kustomize/identity) for a worked example.

## Namespace vs target namespace

Two fields control different things and are usually left unset.

- **`targetNamespace`** sets `spec.targetNamespace` on the Flux Kustomization. Flux rewrites every reconciled resource into that namespace. Use it when the same kustomization layout serves multiple deployment namespaces, for example the same `apps/my-app` path deployed into `staging` in one context and `production` in another.

- **`namespace`** controls where the Flux Kustomization *object itself* lives: the namespace of the `Kustomization` CR, not the namespace of the resources it reconciles. Defaults to the gitops namespace (`system-gitops`). Rarely needed; setting it also breaks `dependsOn` references, which always resolve in the gitops namespace.

```yaml
kustomize:
- name: my-app
  source: core
  path: apps/my-app
  targetNamespace: production    # reconciled resources land in `production`
```

## destroyOnly

A `destroyOnly` kustomization sits in the blueprint but is suppressed during `apply` / `up`. It's only applied during `destroy`, and only long enough to do its work. Typically that's a one-shot job that runs before a stateful component disappears: snapshot a database before the operator tears it down, drain a queue, deregister a load balancer.

```yaml
kustomize:
- name: db-snapshot-on-destroy
  source: core
  path: ops/snapshot
  destroyOnly: true
  dependsOn:
    - postgres
```

`destroyOnly` kustomizations apply in normal dependency order during destroy, then the regular kustomizations get torn down.

## Substitutions

Flux's `postBuild.substitute` lets a Kustomization reference variables in its manifests via `${VAR_NAME}` and have them substituted at reconcile time. Windsor materializes two layers of substitutions automatically:

**`values-common`**: a blueprint-level ConfigMap injected into every kustomization's `postBuild.substituteFrom`. Includes:

| Variable | Source |
|----------|--------|
| `CONTEXT` | active context name |
| `CONTEXT_ID` | `id` from `values.yaml` |
| `DOMAIN` | `dns.domain` |
| `BUILD_ID` | from `windsor build-id`, when set |
| `REGISTRY_URL` | `docker.registry_url` |
| `LOCAL_VOLUME_PATH` | derived from `cluster.workers.volumes` |
| `LOADBALANCER_IP_START` / `_END` / `_RANGE` | from `network.loadbalancer_ips` (skipped on `docker-desktop`) |
| anything under `substitutions.common` in `values.yaml` | user-provided |
| anything under blueprint-level `substitutions:` | user-provided |

**`values-<name>`**: a per-kustomization ConfigMap, populated from the kustomization's `substitutions:` field:

```yaml
kustomize:
- name: my-app
  path: my-app
  substitutions:
    replicas: "3"
    image_tag: "v1.4.2"
```

A manifest under `kustomize/my-app/` can then reference `${replicas}` and `${image_tag}` directly. Substitution values are converted to strings; complex types are JSON-encoded.

`substitutions:` in the user-authored `blueprint.yaml` only accepts literal values. To produce dynamic substitutions (facet expressions, `terraform_output()` calls, anything resolved at compose time), declare them in a facet under `contexts/_template/facets/`. The composer evaluates them and merges the resulting string values into the kustomization's `substitutions` map. See [Blueprint templates](templates.md) and [Facets](facets.md).

## Context-specific patches

Files placed in `contexts/<name>/patches/<name>/` are automatically discovered and added to a kustomization's `patches` — strategic-merge or JSON 6902, detected from the file. They apply after any facet-declared patches. See [Components — Kustomize — Per-context patches](../components/kustomize.md#per-context-patches) for the full mechanics: Flux tier names, file ordering, and current limits.

## Reconciliation

After `apply`, Windsor annotates each blueprint source (`GitRepository` or `OCIRepository`) with `reconcile.fluxcd.io/requestedAt` set to the current timestamp. source-controller picks this up and re-fetches the artifact immediately rather than waiting for the next interval; kustomize-controller then reconciles dependent Kustomizations through its watch on source status. Only sources are annotated; Kustomizations follow automatically.

This is annotation-based, receiver-type-agnostic, and works against any Flux installation. It is best-effort: if the cluster is unreachable, the apply still succeeds.

For workstation contexts, `git-livereload` POSTs to a Flux webhook receiver each time it commits, which provides the same fast-reconcile behavior for in-tree changes that don't go through `windsor apply`.

## Inspecting

```bash
kubectl get gitrepository -A           # source objects
kubectl get ocirepository -A           # OCI sources
kubectl get kustomizations -A          # Flux Kustomization objects
kubectl get kustomization <name> -n system-gitops -o yaml
windsor show kustomization <name>      # the rendered Kustomization Windsor will apply
windsor explain kustomize.<name>.substitutions.<key>
```

Sources and kustomizations both live in the gitops namespace (default `system-gitops`).

## See also

- [`apply`](https://www.windsorcli.dev/reference/cli/commands/apply), [`destroy`](https://www.windsorcli.dev/reference/cli/commands/destroy), [`plan`](https://www.windsorcli.dev/reference/cli/commands/plan), [`show`](https://www.windsorcli.dev/reference/cli/commands/show)
- [Blueprint reference](https://www.windsorcli.dev/reference/cli/blueprint) — full Kustomization schema
- [Blueprint templates](templates.md) — facet-driven composition
- [Components — Kustomize — Per-context patches](../components/kustomize.md#per-context-patches) — the full context-patches mechanics
- [Flux systems](flux-systems.md) — the multi-tier `flux:` entries, and how they differ from this passthrough
- [Flux Kustomization docs](https://fluxcd.io/flux/components/kustomize/kustomizations/)
