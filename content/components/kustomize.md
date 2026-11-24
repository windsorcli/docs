---
title: Kustomize
description: Declaring, running, and operating Kustomizations in a blueprint.yaml, with patches, substitutions, and reconciliation.
---

You have Kubernetes manifests, or are about to write them, and you want Flux to apply them in one context on top of what `core` or another blueprint already provides. You declare them as a [component](terraform.md) under `kustomize:` in the context's `blueprint.yaml`. When the same components must work across several contexts, including ones you haven't written yet, they move into a [blueprint](../blueprints/overview.md).

Windsor turns each entry under `kustomize:` into one Flux [`Kustomization`](https://fluxcd.io/flux/components/kustomize/kustomizations/) resource that points at a path in a blueprint source, and Flux reconciles the resources at that path onto the cluster. The mapping is one to one. Facets usually contribute multi-tier `flux:` system entries instead, which [Flux systems](../blueprints/flux-systems.md) covers.

## Declare components

Kustomizations live in source repositories, not the project tree. A local one sits under `kustomize/` in the project root and is referenced without a `source:`. This entry declares the local `my-app` kustomization with its `prometheus` component.

```yaml
kustomize:
- name: my-app
  path: my-app
  components:
    - prometheus
```

The `components:` field belongs to Kustomize, not Windsor. It lists [Kustomize components](https://kubectl.docs.kubernetes.io/guides/config_management/components/) to include from the kustomization's directory, here the `prometheus/` folder under `kustomize/my-app/`.

To pull a kustomization from a remote source, the entry references the source and Windsor resolves the path inside it. This entry takes `csi` from `core` with its `longhorn` component.

```yaml
kustomize:
- name: csi
  source: core
  path: csi/install
  components:
    - longhorn
```

For the full Kustomization schema (every field, type, and default) see the [blueprint reference](https://www.windsorcli.dev/reference/cli/blueprint).

### Folder layout

A local entry's files sit under `kustomize/` in the project root, and per-context patches sit under `contexts/<name>/patches/`. This tree shows both for the `my-app` entry in a `local` context.

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

The `prometheus/` folder is the Kustomize component that the `my-app` entry lists.

### Per-context patches

Windsor adds every file in `contexts/<context>/patches/<name>/` to the `patches` of the kustomization called `<name>`. Each `.yaml` or `.yml` file is one patch, and Windsor ignores subdirectories and other extensions. Files apply in filename order, which matters when two patches touch the same field.

`<name>` is a kustomization name or a Flux system tier: `<system>-install`, `<system>-resources`, `<system>-resources-<variant>`, or the bare `<system>`. A bare system name resolves to the install tier if the system has one, and otherwise to its only resources variant. If the system has more than one resources variant, Windsor leaves the bare name unresolved.

A *strategic-merge patch* is ordinary Kubernetes resource YAML, and Windsor merges its fields into the matching resource in the kustomization output. This patch sets the `my-app` Deployment to five replicas.

```yaml
# contexts/local/patches/my-app/increase-replicas.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  replicas: 5
```

A *JSON 6902 patch* carries a resource header (`apiVersion`, `kind`, `metadata`) to select the target, plus `patches:`, a list of [RFC 6902](https://www.rfc-editor.org/rfc/rfc6902) operations. The target matches only on `kind`, `metadata.name`, and `metadata.namespace`. There are no `group`, `version`, label, or annotation selectors. This patch makes the same replica change as an RFC 6902 operation.

```yaml
# contexts/local/patches/my-app/json-patch.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
  namespace: default
patches:
  - op: replace
    path: /spec/replicas
    value: 5
```

Windsor tells the two formats apart by the document layout. It always treats a file with no `kind` as a raw strategic-merge patch, even if the file has a `patches:` field. Context patches apply after both facet-declared and blueprint-declared patches, so they always win on a conflicting field.

When a patch directory matches no kustomization or Flux tier name, Windsor prints one warning, skips the directory, and composition still succeeds. Windsor skips a patch file with invalid YAML, or one it can't read, with no warning at all. If a patch seems not to apply, check the output of `windsor show kustomization <name>`.

## Run components

`windsor apply` (or [`windsor up`](https://www.windsorcli.dev/reference/cli/commands/up) for workstation contexts) installs every kustomization in dependency order. `windsor destroy` removes them all in reverse-topological order. Use `windsor apply kustomize <name>` or `windsor destroy kustomize <name>` to target a single kustomization.

## Add-on components

An add-on's README, in `kustomize/<name>` of the blueprint's repository, splits the add-on into named components. Identity, for example, has `keycloak-operator`, `keycloak`, and `oidc-federation`. This meaning is specific to Windsor add-ons and differs from the Kustomize `components:` field.

Each named component is a distinct resource inside the add-on, such as a HelmRelease, a Job, or an HTTPRoute. Its own condition gates it, for example a config flag, another add-on being enabled, or a platform choice. The condition decides whether the component exists in your context at all, not how it is patched.

The Catalog guides cover only what you configure in `values.yaml`. For the full list of an add-on's components, read its README. The [Identity README](https://github.com/windsorcli/core/tree/main/kustomize/identity) is a worked example.

## Namespace vs target namespace

Two fields control different namespaces, and most entries leave both unset.

`targetNamespace` sets `spec.targetNamespace` on the Flux Kustomization, and Flux rewrites every reconciled resource into that namespace. Use it when one kustomization layout serves several deployment namespaces, for example the same `apps/my-app` path deployed into `staging` in one context and `production` in another. This entry sends the `my-app` resources to `production`.

```yaml
kustomize:
- name: my-app
  source: core
  path: apps/my-app
  targetNamespace: production    # reconciled resources land in `production`
```

`namespace` sets where the Flux Kustomization object itself lives. That is the namespace of the `Kustomization` CR, not of the resources it reconciles, and it defaults to the gitops namespace, `system-gitops`. Few entries need it. Setting it also breaks `dependsOn` references, which always resolve in the gitops namespace.

## destroyOnly

A `destroyOnly` kustomization sits in the blueprint, but Windsor skips it during `apply` and `up`. Windsor applies it only during `destroy`, and only long enough to do its work. It is usually a one-shot job that runs before a stateful component disappears, for example to snapshot a database before the operator tears it down, drain a queue, or deregister a load balancer. This entry runs a snapshot job that depends on `postgres`.

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

Flux's `postBuild.substitute` replaces `${VAR_NAME}` references in a Kustomization's manifests at reconcile time. Windsor supplies the values in two layers, each a ConfigMap.

The first layer, `values-common`, is a blueprint-level ConfigMap that Windsor adds to every kustomization's `postBuild.substituteFrom`. It holds these variables.

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

The second layer, `values-<name>`, is a per-kustomization ConfigMap that Windsor fills from the kustomization's `substitutions:` field. This entry sets two substitutions for `my-app`.

```yaml
kustomize:
- name: my-app
  path: my-app
  substitutions:
    replicas: "3"
    image_tag: "v1.4.2"
```

A manifest under `kustomize/my-app/` can then reference `${replicas}` and `${image_tag}` directly. Substitution values are converted to strings; complex types are JSON-encoded.

`substitutions:` in the user-authored `blueprint.yaml` only accepts literal values. To produce dynamic substitutions (facet expressions, `terraform_output()` calls, anything resolved at compose time), declare them in a facet under `contexts/_template/facets/`. The composer evaluates them and merges the resulting string values into the kustomization's `substitutions` map. See [Blueprint templates](../blueprints/templates.md) and [Facets](../blueprints/facets.md).

## Reconciliation

After `apply`, Windsor annotates each blueprint source (`GitRepository` or `OCIRepository`) with `reconcile.fluxcd.io/requestedAt` set to the current timestamp. source-controller picks this up and re-fetches the artifact immediately rather than waiting for the next interval; kustomize-controller then reconciles dependent Kustomizations through its watch on source status. Windsor annotates only the sources, and the Kustomizations follow.

Because the trigger is an annotation, it works against any Flux installation, whatever receiver types it has. It is best-effort: if the cluster is unreachable, the apply still succeeds.

For workstation contexts, `git-livereload` POSTs to a Flux webhook receiver each time it commits, which provides the same fast-reconcile behavior for in-tree changes that don't go through `windsor apply`.

## Inspecting

These commands show the Flux sources and Kustomizations on the cluster, and what Windsor renders for one entry.

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

- [Terraform](terraform.md): the other kind of component
- [Blueprints](../blueprints/overview.md): turning a context's components into a template that many contexts share
- [`apply`](https://www.windsorcli.dev/reference/cli/commands/apply), [`destroy`](https://www.windsorcli.dev/reference/cli/commands/destroy), [`plan`](https://www.windsorcli.dev/reference/cli/commands/plan), [`show`](https://www.windsorcli.dev/reference/cli/commands/show)
- [Blueprint reference](https://www.windsorcli.dev/reference/cli/blueprint): the full Kustomization schema
- [Blueprint templates](../blueprints/templates.md): facet-driven composition
- [Flux systems](../blueprints/flux-systems.md): the multi-tier `flux:` entries, and how they differ from a one-to-one entry
- [Flux Kustomization docs](https://fluxcd.io/flux/components/kustomize/kustomizations/)
