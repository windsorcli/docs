---
title: Lifecycle
description: How init, up, bootstrap, apply, plan, destroy, and down fit together.
---

This page groups the lifecycle commands into the phases they represent. Knowing which phase a command belongs to is the shortest path through the CLI.

| Phase | Command | What it does |
|---|---|---|
| Scaffold | [`init`](/reference/cli/commands/init) | Creates the context, writes `windsor.yaml`, marks the directory trusted. |
| Workstation | [`up`](/reference/cli/commands/up) / [`down`](/reference/cli/commands/down) | Starts/stops the local VM and container runtime. Workstation contexts only. |
| First-run | [`bootstrap`](/reference/cli/commands/bootstrap) | End-to-end install for non-workstation contexts. Two-phase apply when a `backend` component is in play. |
| Install | [`apply`](/reference/cli/commands/apply) | Runs Terraform components, then installs the Flux blueprint. |
| Inspect | [`plan`](/reference/cli/commands/plan) / [`show`](/reference/cli/commands/show) / [`explain`](/reference/cli/commands/explain) | Previews changes, prints rendered resources, traces values. |
| Tear down | [`destroy`](/reference/cli/commands/destroy) | Destroys live infrastructure (Terraform + Flux). |

## Workstation contexts

A workstation context (typically `local`) runs a VM-backed Kubernetes cluster on your machine. It uses `up` and `down`.

```bash
windsor init local
windsor up                      # start VM, terraform, install blueprint
# ... work ...
windsor down                    # stop VM, clean up local artifacts
```

`up` is workstation-only. It starts the configured VM driver, runs Terraform for the workstation infrastructure, and installs the blueprint via Flux. Pass `--wait` to block until kustomizations report ready.

`down` stops the VM and cleans local artifacts. It does not destroy live cloud resources — for that, run `destroy` first.

## Non-workstation contexts

Staging, production, and any other deployment context does not run a VM. The first run uses `bootstrap`; subsequent reconciles use `apply`.

```bash
windsor init staging
windsor set context staging
windsor bootstrap --wait        # first run: handles backend, migrates state
# ... later reconciles ...
windsor apply --wait
# ... and tear down ...
windsor destroy --confirm=staging
```

`bootstrap` handles the chicken-and-egg case where the remote Terraform backend (S3 bucket, DynamoDB table, etc.) is itself created by Terraform. It applies the `backend` component against local state, migrates state to the configured backend, then runs the rest of `apply`. When no `backend` component is declared, `bootstrap` is equivalent to `apply`.

`apply` does the same work as `up` does for a workstation — Terraform components, then Flux blueprint — minus the VM management. It supports targeted runs:

```bash
windsor apply terraform cluster        # one terraform component
windsor apply kustomize observability  # one Flux kustomization
```

## Inspect before you apply

`windsor plan` previews changes without applying. With no argument it prints a summary across all components; with a name it streams the full plan for that component. `windsor show` prints rendered resources, and `windsor explain <path>` traces a single value back to where it came from in the composition.

See the per-command reference for the full flag set.

## Tear down

`destroy` requires confirmation — interactively or via `--confirm=<context>` for CI. For workstation contexts, `destroy` then `down` is the typical full teardown:

```bash
windsor destroy --confirm=local
windsor down
```

For non-workstation contexts, `destroy` is the whole story.

## See also

- [Contexts](/contexts/contexts) — workstation vs non-workstation, switching contexts
- [Workstation overview](/workstation/overview) — VM driver options and topology
- [`init`](/reference/cli/commands/init), [`bootstrap`](/reference/cli/commands/bootstrap), [`apply`](/reference/cli/commands/apply), [`destroy`](/reference/cli/commands/destroy), [`up`](/reference/cli/commands/up), [`down`](/reference/cli/commands/down)
