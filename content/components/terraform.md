---
title: Terraform
description: Adding your own Terraform modules to a consumed blueprint's blueprint.yaml, without authoring a template.
---

This is the entry point if you already have Terraform modules — or are about to write them — and want Windsor to run them, without authoring a reusable blueprint. You're consuming `core` (or another blueprint) and adding your own modules on top, directly in one context's `blueprint.yaml`. No facets, no schema, no `_template/` folder, and no other context has to share what you write here. That's [Blueprints](../blueprints/overview.md), for when the same components need to work across contexts you haven't written yet. See [Kustomize](kustomize.md) for the other half of a component.

Add a `terraform:` entry to `blueprint.yaml` for each module the context depends on:

```yaml
terraform:
- source: core
  path: cluster/talos
- source: core
  path: gitops/flux
  dependsOn:
    - cluster/talos
- path: example/my-app          # local module under terraform/
- name: backend                 # opt-in formal name (any unique slug)
  source: core
  path: aws/state
  inputs:
    bucket_name: ${cluster.name}-state
```

A component with no `source:` resolves to `terraform/<path>` in your project; with `source:`, it resolves into the named blueprint source. `inputs` takes literal values or `${...}` expressions evaluated at compose time. The full schema is in the [blueprint reference](https://www.windsorcli.dev/reference/cli/blueprint).

See [Blueprints — Terraform](../blueprints/terraform.md) for running, inspecting, and reading outputs between components.

## Per-context overrides

`contexts/<name>/terraform/<component-id>.tfvars` (or `.tfvars.json`) overrides one component's inputs, on top of whatever `inputs:` already set in `blueprint.yaml`. Windsor passes it as an extra `-var-file`, not instead of the generated one — Terraform applies var-files in order and the last one wins per variable, so the override file only needs the variables it's actually changing. `<component-id>` is the component's `name` if it has one, else its `path`:

```text
contexts/staging/terraform/
├── cluster.tfvars              # overrides a component named "cluster"
└── cluster/talos.tfvars        # overrides the same component by path, if unnamed
```

The override only reaches `plan`, `refresh`, `destroy`, and `import`. `apply` takes no var-files — it applies the plan `plan` already produced, so set the override before planning, not between plan and apply. See [Command model](../provisioning/workflow.md) for what each command does.

`contexts/<name>/backend.tfvars` overrides the Terraform backend config the same way, checked before the equivalent `contexts/<name>/terraform/backend.tfvars`. `contexts/<name>/terraform/.env` sets environment variables for every Terraform command run in that context — the same idea as a project `.env` file, scoped one level deeper. See [Environment injection](../contexts/environment-injection.md) for what else Windsor exports, including `TF_VAR_*`.

## See also

- [Kustomize](kustomize.md) — the other half of a component
- [Blueprints](../blueprints/overview.md) — turning a componentized context into a reusable, multi-context template
- [Blueprints — Terraform](../blueprints/terraform.md) — running components, reading outputs, the state backend
- [Command model](../provisioning/workflow.md) — the commands that apply what you declared here
- [Environment injection](../contexts/environment-injection.md) — what Windsor exports into your shell
