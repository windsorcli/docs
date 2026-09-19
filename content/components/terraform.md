---
title: Terraform
description: Declaring, running, and operating Terraform components in a blueprint.yaml — entries, outputs, the state backend, and bootstrap.
---

This is the entry point if you already have Terraform modules — or are about to write them — and want Windsor to run them, without authoring a reusable blueprint. You're consuming `core` (or another blueprint) and adding your own modules on top, directly in one context's `blueprint.yaml`. No facets, no schema, no `_template/` folder, and no other context has to share what you write here. That's [Blueprints](../blueprints/overview.md), for when the same components need to work across contexts you haven't written yet. See [Kustomize](kustomize.md) for the other half of a component.

## Declare components

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

### Per-context overrides

`contexts/<name>/terraform/<component-id>.tfvars` (or `.tfvars.json`) overrides one component's inputs, on top of whatever `inputs:` already set in `blueprint.yaml`. Windsor passes it as an extra `-var-file`, not instead of the generated one — Terraform applies var-files in order and the last one wins per variable, so the override file only needs the variables it's actually changing. `<component-id>` is the component's `name` if it has one, else its `path`:

```text
contexts/staging/terraform/
├── cluster.tfvars              # overrides a component named "cluster"
└── cluster/talos.tfvars        # overrides the same component by path, if unnamed
```

The override only reaches `plan`, `refresh`, `destroy`, and `import`. `apply` takes no var-files — it applies the plan `plan` already produced, so set the override before planning, not between plan and apply. See [Command model](../provisioning/workflow.md) for what each command does.

`contexts/<name>/backend.tfvars` overrides the Terraform backend config the same way, checked before the equivalent `contexts/<name>/terraform/backend.tfvars`. `contexts/<name>/terraform/.env` sets environment variables for every Terraform command run in that context — the same idea as a project `.env` file, scoped one level deeper. See [Environment injection](../contexts/environment-injection.md) for what else Windsor exports, including `TF_VAR_*`.

## Run components

Windsor builds the stack sequentially, threading each component's Terraform output values to the input values of the components that depend on it. These commands drive it:

| Command | Effect |
|---------|--------|
| [`windsor plan terraform [component]`](https://www.windsorcli.dev/reference/cli/commands/plan) | `init` + `plan` for one component, or all if omitted. `--summary` prints a table; otherwise streams full output. New components show `(new)`. |
| [`windsor apply terraform <component>`](https://www.windsorcli.dev/reference/cli/commands/apply) | `init` + `plan` + `apply` for the named component. |
| [`windsor apply`](https://www.windsorcli.dev/reference/cli/commands/apply) | Apply every component in dependency order, then install the Flux blueprint. |
| [`windsor destroy terraform [component]`](https://www.windsorcli.dev/reference/cli/commands/destroy) | Destroy one component, or all in reverse-topological order. `--confirm=<token>` skips the interactive prompt. |
| [`windsor up`](https://www.windsorcli.dev/reference/cli/commands/up) / [`windsor down`](https://www.windsorcli.dev/reference/cli/commands/down) | Workstation contexts only. `up` drives Terraform + Flux for the workstation; `down` stops the VM. |
| [`windsor bootstrap`](https://www.windsorcli.dev/reference/cli/commands/bootstrap) | First-run setup — see [Bootstrap](#bootstrap) below. |

`apply` runs against a saved plan, so Terraform never prompts for approval. `destroy` is different: it passes `-auto-approve` and gates on a confirmation token (`--confirm=<token>` or an interactive prompt). A `terraform destroy` run directly in a `windsor env`-managed shell gets no `-auto-approve` in `TF_CLI_ARGS_destroy`, so Terraform's own prompt appears.

## Read another component's outputs

A component can read another's outputs through the `terraform_output` helper, inside a [facet](../blueprints/facets.md) expression:

```yaml
terraform:
- name: cluster
  source: core
  path: cluster/talos
- name: app
  path: example/my-app
  dependsOn: [cluster]
  inputs:
    api_endpoint: ${terraform_output("cluster", "endpoint")}
    mirrors: ${terraform_output("workstation", "registries") ?? {}}
```

Windsor walks components in dependency order. By the time `app` evaluates `terraform_output("cluster", "endpoint")`, the `cluster` component's `terraform output -json` has been read, and the result becomes `TF_VAR_api_endpoint`. The `??` operator supplies a default when the upstream component hasn't been applied yet, so the dependent component can still plan.

There is no bare-path form. `${terraform.<other>.outputs.<key>}` does not exist; the `terraform_output()` helper is the only access, and only inside facet expressions.

## State backend

Set the backend in the context's `windsor.yaml`:

```yaml
terraform:
  backend:
    type: s3              # local | s3 | kubernetes | azurerm
    s3:
      bucket: my-tf-state
      key: contexts/staging
      region: us-east-2
```

State is keyed per-component and isolated within a single context. Windsor writes the backend wiring into a generated `backend_override.tf` next to each module ([Folder layout](#folder-layout) shows where), so the module itself never needs a hard-coded `backend` block.

`--platform` sets a default backend at `init` / `bootstrap` / `up` time when you haven't set one explicitly:

| Platform | Default backend |
|----------|-----------------|
| `aws` | `s3` |
| `azure` | `azurerm` |
| `metal`, `docker`, `incus` | `kubernetes` (each component's state is stored as a Secret in the cluster) |
| `gcp`, `none`, unset | not defaulted (effectively `local`) |

Override it at init with `--backend`, with `--set terraform.backend.type=...` on `bootstrap`, or by editing `windsor.yaml` directly.

## Under the hood

Windsor drives Terraform from a generated working area under `.windsor/`. Each component has its own module shim, tfvars, and backend config there.

### Folder layout

Two trees matter: your project source, and Windsor's working area.

```text
contexts/
└── local/
    ├── blueprint.yaml          # required after `windsor init`
    ├── values.yaml             # context values consumed by facets
    └── terraform/              # OPTIONAL: hand-authored .tfvars overrides
        └── cluster/talos.tfvars
terraform/
└── database/postgres/
    ├── main.tf
    └── variables.tf
.windsor/
└── contexts/
    └── local/
        ├── terraform/<component>/  # generated module shim + terraform.tfvars
        │   ├── main.tf
        │   ├── variables.tf
        │   ├── outputs.tf
        │   ├── backend_override.tf
        │   └── terraform.tfvars
        └── .terraform/<component>/ # provider plugins, modules, tfstate (local backend)
            └── terraform.tfstate
```

Modules under `terraform/` are local to the project, referenced with a `path:` and no `source:`. Modules pulled from blueprint sources (OCI artifacts or Git repositories) are unpacked as shims into `.windsor/contexts/<name>/terraform/<component>/`. Each shim carries a generated `terraform.tfvars` and a `backend_override.tf` pointing at the configured [state backend](#state-backend).

The `terraform/` folder under a context holds hand-authored overrides — per-component tfvars, backend config, a scoped `.env` file. See [Per-context overrides](#per-context-overrides) above.

### Generated tfvars and variables

Windsor materializes each component's evaluated `inputs:` into the generated `terraform.tfvars`, then sets `TF_CLI_ARGS_*` so every Terraform command picks up the right `-var-file` automatically. The same inputs are exported per-component as `TF_VAR_<input>`.

Windsor also injects a set of context variables: `TF_VAR_context`, `TF_VAR_context_id`, `TF_VAR_context_path`, `TF_VAR_project_root`, and `TF_VAR_os_type`. During an `apply` or `destroy` it adds `TF_VAR_operation`, set to `apply` or `destroy`, so a component can branch on the lifecycle phase. To see everything exported for the current context:

```bash
windsor env
```

For how these are emitted on each shell prompt, see [environment injection](../contexts/environment-injection.md).

### State locking

Windsor passes `-lock-timeout` to every state-mutating Terraform command, and to `init`, so contended remote state waits instead of failing immediately. The wait is `terraform.lock.timeout`, a Go duration string that defaults to `5m`:

```yaml
terraform:
  lock:
    timeout: 10m
```

This is separate from Windsor's own per-context [stack lock](../maintenance/destroy.md#safety-and-concurrency), which serializes concurrent `windsor` commands before Terraform's state lock ever engages.

### Bootstrap

`windsor bootstrap` handles the chicken-and-egg case where the configured remote backend lives in infrastructure Terraform itself must create, such as an S3 bucket for state or an Azure Storage account.

When the blueprint declares a component named `backend`, bootstrap runs in two phases:

1. **Phase 1** overrides `terraform.backend.type` to `local` in memory and applies only the `backend` component, which materializes the remote state store (bucket, table, etc.).
2. **Phase 2** restores the configured backend type and runs `terraform init -migrate-state -force-copy` for the `backend` component, moving its state to remote. The on-disk `windsor.yaml` is never mutated.

The next `apply` or `up` initializes the remaining components directly against the remote backend; they have never been applied, so there is nothing to migrate.

With no `backend` component, bootstrap behaves like `apply --wait` against whatever backend is configured. It is safe to run repeatedly: a later run detects the migrated backend and skips Phase 1.

```bash
windsor bootstrap                    # current context
windsor bootstrap staging            # switch context, then bootstrap
windsor bootstrap --platform aws --blueprint ghcr.io/org/blueprint:v1.2.0
```

### Workstation network callback

When the blueprint includes a Terraform component representing the workstation itself (component id `workstation`), host and guest networking and DNS are deferred until after that component applies. A hook then configures host routes, guest networking, and DNS for the active platform (Colima or Docker), using the DNS address from the component's outputs when it is available.

This is workstation-context behavior only; non-workstation contexts skip the callback.

### OpenTofu (experimental)

Windsor can drive OpenTofu instead of Terraform. Setting `terraform.driver: opentofu` in the root `windsor.yaml` selects it; otherwise Windsor auto-detects from `$PATH`, preferring `terraform` and falling back to `tofu`. Support is experimental, and behavior may diverge from Terraform on edge cases.

## See also

- [Kustomize](kustomize.md) — the other half of a component
- [Blueprints](../blueprints/overview.md) — turning a componentized context into a reusable, multi-context template
- [Command model](../provisioning/workflow.md) — the commands that apply what you declared here
- [Environment injection](../contexts/environment-injection.md) — what Windsor exports into your shell
- [Workstation overview](../workstation/overview.md) — workstation-specific Terraform components
- [Blueprint reference](https://www.windsorcli.dev/reference/cli/blueprint) — `TerraformComponent` schema
