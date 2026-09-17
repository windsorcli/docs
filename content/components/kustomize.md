---
title: Kustomize
description: Adding your own Kustomizations to a consumed blueprint's blueprint.yaml, without authoring a template.
---

This is the entry point if you already have Kubernetes manifests — or are about to write them — and want Windsor to run them through Flux, without authoring a reusable blueprint. You're consuming `core` (or another blueprint) and adding your own kustomizations on top, directly in one context's `blueprint.yaml`. No facets, no schema, no `_template/` folder, and no other context has to share what you write here. That's [Blueprints](../blueprints/overview.md), for when the same components need to work across contexts you haven't written yet. See [Terraform](terraform.md) for the other half of a component.

Each entry under `kustomize:` becomes a Flux [`Kustomization`](https://fluxcd.io/flux/components/kustomize/kustomizations/) resource that points at a path in a blueprint source. `windsor apply` (or `windsor up` for workstation contexts) installs every kustomization in dependency order.

Kustomizations live in source repositories, not the project tree. A local one sits under `kustomize/` in the project root and is referenced without a `source:`:

```yaml
kustomize:
- name: my-app
  path: my-app
  components:
    - prometheus
```

To pull a kustomization from a remote source, name the source and let Windsor resolve the path inside it:

```yaml
kustomize:
- name: csi
  source: core
  path: csi
  components:
    - longhorn
```

For the full Kustomization schema (every field, type, and default) see the [blueprint reference](https://www.windsorcli.dev/reference/cli/blueprint). See [Blueprints — Kustomize](../blueprints/kustomize.md) for substitutions and add-on components.

## Per-context patches

Files placed in `contexts/<name>/patches/<name>/` are discovered automatically and added to a kustomization's `patches`. Each `.yaml`/`.yml` file contributes one patch; subdirectories and other extensions are ignored. Files apply in filename order, which matters when two patches touch the same field.

`<name>` can be a plain kustomization name, or a Flux system tier: `<system>-install`, `<system>-resources`, `<system>-resources-<variant>`, or the bare `<system>` name (resolves to the install tier if one exists, otherwise the sole resources variant — left unresolved if there's more than one).

A **strategic-merge patch** is standard Kubernetes resource YAML; its fields merge into the matching resource in the kustomization output:

```yaml
# contexts/local/patches/my-app/increase-replicas.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  replicas: 5
```

A **JSON 6902 patch** carries a resource header (`apiVersion`, `kind`, `metadata`) to select the target, plus `patches:`, an [RFC 6902](https://www.rfc-editor.org/rfc/rfc6902) operation list. The target can only match on `kind`, `metadata.name`, and `metadata.namespace` — no `group`, `version`, or label/annotation selectors:

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

Windsor detects the format from the document layout: a file with no `kind` is always treated as a raw strategic-merge patch, never JSON 6902, even if it has a `patches:` field. Context patches apply after facet- and blueprint-declared patches, so they always win on a conflicting field.

A patch directory that doesn't match any kustomization or Flux tier name prints one warning and is skipped; composition still succeeds. A patch file with invalid YAML, or one Windsor can't read, is skipped with no warning at all. Check `windsor show kustomization <name>` if a patch doesn't seem to have applied.

## See also

- [Terraform](terraform.md) — the other half of a component
- [Blueprints](../blueprints/overview.md) — turning a componentized context into a reusable, multi-context template
- [Blueprints — Kustomize](../blueprints/kustomize.md) — substitutions and add-on components
- [Command model](../provisioning/workflow.md) — the commands that apply what you declared here
