---
title: Terraform
description: How Windsor drives Terraform — components, generated tfvars, backend configuration, and the bootstrap workflow.
---

Windsor invokes Terraform on your behalf. You declare components in `blueprint.yaml`; Windsor generates per-component shims, materializes a `terraform.tfvars` for each, sets the right `TF_*` environment variables, and runs `init`, `plan`, `apply`, and `destroy` against the right module in the right order.

OpenTofu support is **experimental**. Set `terraform.driver: opentofu` in the root `windsor.yaml`, or let Windsor auto-detect from `$PATH` — it prefers `terraform`, falls back to `tofu`. Behavior may diverge from Terraform on edge cases.

## Folder layout

Two trees matter — your project source, and Windsor's working area.

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

Modules under `terraform/` are local to the project; reference them with a `path:` and no `source:`. Modules pulled from blueprint sources (OCI artifacts or Git repositories) are unpacked as shims into `.windsor/contexts/<name>/terraform/<component>/`.

`contexts/<name>/terraform/<component>.tfvars` is an optional user override. When present, Windsor consumes it instead of the generated tfvars.

## Declaring components

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

Components without a `source:` resolve to `terraform/<path>` in the project; with `source:`, they resolve into the named blueprint source. `inputs` accepts both literal values and `${...}` expressions evaluated at compose time. See the [blueprint reference](/reference/cli/blueprint) for the full schema.

## Lifecycle commands

| Command | Effect |
|---------|--------|
| [`windsor plan terraform [component]`](/reference/cli/commands/plan) | `init` + `plan` for one component, or all if omitted. `--summary` prints a table; otherwise streams full output. New components show `(new)`. |
| [`windsor apply terraform <component>`](/reference/cli/commands/apply) | `init` + `plan` + `apply` for the named component. |
| [`windsor apply`](/reference/cli/commands/apply) | Apply every component in dependency order, then install the Flux blueprint. |
| [`windsor destroy terraform [component]`](/reference/cli/commands/destroy) | Destroy one component, or all in reverse-topological order. `--confirm=<token>` skips the interactive prompt. |
| [`windsor up`](/reference/cli/commands/up) / [`windsor down`](/reference/cli/commands/down) | Workstation contexts only. `up` drives Terraform + Flux for the workstation; `down` stops the VM. |
| [`windsor bootstrap`](/reference/cli/commands/bootstrap) | First-run setup — see [Bootstrap](#bootstrap) below. |

From `apply`, Windsor runs `terraform apply <plan-file>` against a saved plan — Terraform never prompts and `-auto-approve` is not needed. From `destroy`, Windsor passes `-auto-approve` and owns the confirmation gate itself (`--confirm` or an interactive prompt). If you run `terraform destroy` directly inside a `windsor env`-managed shell, Windsor leaves `TF_CLI_ARGS_destroy` empty so Terraform's own prompt appears.

## Variables and environment

Windsor materializes inputs to a generated `terraform.tfvars` next to each module shim and points Terraform at the right plan/apply/destroy args via `TF_CLI_ARGS_*`. You don't pass `-var-file` yourself.

Per-component `TF_VAR_<input>` variables are materialized from the component's evaluated `inputs:`. Windsor also injects `TF_VAR_context`, `TF_VAR_context_id`, `TF_VAR_context_path`, `TF_VAR_project_root`, `TF_VAR_os_type`, and `TF_VAR_operation` (set to `apply` or `destroy` so components can branch on lifecycle phase). For the full table see the [environment reference](/reference/cli/environment#terraform).

To inspect what Windsor exports for the current context:

```bash
windsor env
```

## Cross-component outputs

A component can read another component's outputs through the `terraform_output` expression helper, used inside [facet](/blueprints/facets) expressions:

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

Windsor walks components in dependency order. When `terraform_output("cluster", "endpoint")` is evaluated for `app`, the `cluster` component's `terraform output -json` is read at evaluation time and the result becomes `TF_VAR_api_endpoint`. The `??` operator supplies a default when the upstream component hasn't been applied yet — this lets the dependent component still plan.

The bare path syntax `${terraform.<other>.outputs.<key>}` does not exist — only the `terraform_output()` helper is supported, and only inside facet expressions.

## State backend

Configure the state backend in the context's `windsor.yaml`:

```yaml
terraform:
  backend:
    type: s3              # local | s3 | kubernetes | azurerm
    s3:
      bucket: my-tf-state
      key: contexts/staging
      region: us-east-2
```

Windsor writes a `backend_override.tf` next to each generated module shim that points at the configured backend, so the underlying Terraform module doesn't need a hard-coded `backend` block. State is keyed per-component, isolated within a single context.

Default backend by `platform`, applied at `windsor init` / `windsor bootstrap` / `windsor up` time when no explicit backend is set:

| Platform | Default backend |
|----------|-----------------|
| `aws` | `s3` |
| `azure` | `azurerm` |
| `metal`, `docker`, `incus` | `kubernetes` (each component's state is stored as a Secret in the cluster) |
| `gcp`, `none`, unset | not defaulted (effectively `local`) |

Override at init time with `--backend`, via `--set terraform.backend.type=...` on `bootstrap`, or by editing `windsor.yaml` directly.

## State locking

Windsor passes `-lock-timeout` to every state-mutating Terraform command (and to `init`), so a contended remote state waits instead of failing immediately. The wait is set by `terraform.lock.timeout`, a Go duration string that defaults to `5m`:

```yaml
terraform:
  lock:
    timeout: 10m
```

This is separate from Windsor's own per-context [stack lock](/contexts/lifecycle#safety-and-concurrency), which serializes concurrent `windsor` commands before Terraform's state lock engages.

## Bootstrap

`windsor bootstrap` handles the chicken-and-egg case where the configured remote backend lives in infrastructure that Terraform itself must create — for example, an S3 bucket for state, or an Azure Storage account.

When the blueprint declares a component named `backend`, bootstrap runs in two phases:

1. **Phase 1** — Override `terraform.backend.type` to `local` in memory and apply only the `backend` component. This materializes the remote state store (bucket, table, etc.).
2. **Phase 2** — Restore the configured backend type and `terraform init -migrate-state -force-copy` for the `backend` component, moving its state to remote. The on-disk `windsor.yaml` is never mutated.

The next `apply` / `up` initializes the rest of the components directly against the configured remote backend with no migration needed — they haven't been applied yet.

When the blueprint has no `backend` component, bootstrap behaves like `apply --wait` against whatever backend is configured. It is also safe to run repeatedly; subsequent invocations detect the migrated backend and skip Phase 1.

```bash
windsor bootstrap                    # current context
windsor bootstrap staging            # switch context, then bootstrap
windsor bootstrap --platform aws --blueprint ghcr.io/org/blueprint:v1.2.0
```

## Workstation network callback

When the blueprint includes a Terraform component that represents the workstation itself (component id `workstation`), host/guest networking and DNS are deferred until after that component applies. A hook then configures host routes, guest networking, and DNS for the active platform (Colima, Docker, etc.) using the DNS address from the component's outputs when available.

This is workstation-context behavior only; non-workstation contexts skip the callback.

## See also

- [Lifecycle](/contexts/lifecycle) — phase-by-phase command map
- [Environment reference](/reference/cli/environment) — full env table including cloud providers
- [Workstation overview](/workstation/overview) — workstation-specific Terraform components
- [Blueprint reference](/reference/cli/blueprint) — `TerraformComponent` schema
