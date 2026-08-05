---
title: Lifecycle
description: The lifecycle commands grouped by purpose, and which ones a workstation context uses versus a cloud or metal context.
---

A Windsor context has a short lifecycle: scaffold it, provision its infrastructure and install the blueprint, then tear it down. Which commands do that work depends on whether the context runs a local workstation VM or targets cloud infrastructure. The path splits right after `windsor init`:

```mermaid
flowchart TB
  Init["windsor init<br/>scaffold the context"] --> Q{workstation<br/>context?}
  subgraph WS["Workstation (local)"]
    direction LR
    Up["up<br/>VM + Terraform"] --> CN["configure network<br/>host route + DNS (sudo)"] --> Up2["up<br/>re-run: install Flux"] --> Down["down<br/>stop VM, keep state"]
  end
  subgraph Cloud["Non-workstation (cloud / metal)"]
    direction LR
    Boot["bootstrap<br/>first run + backend"] --> Apply["apply<br/>reconcile"]
  end
  Q -->|yes| Up
  Q -->|no| Boot
  WS --> Destroy["destroy<br/>remove infrastructure"]
  Cloud --> Destroy
```

## A workstation context

A workstation context (typically `local`, or any name starting with `local-`) runs a VM-backed Kubernetes cluster on your machine. Its lifecycle is `up` and `down`:

```bash
windsor init local
windsor up                      # start VM + Terraform; halts if network setup is needed
windsor configure network       # first run only: prompts for sudo
windsor up                      # re-run to install the blueprint via Flux
# ... work ...
windsor down                    # stop VM, clean up local artifacts
```

`up` starts the configured VM driver, runs Terraform for the workstation infrastructure, and installs the blueprint via Flux. Pass `--wait` to block until every kustomization reports ready.

Host networking and DNS need elevation, which `up` does not request on its own. It hands that to [`configure network`](https://www.windsorcli.dev/reference/cli/commands/configure-network) instead: sudo on macOS/Linux, an Administrator PowerShell on Windows. What you do next depends on the runtime:

- **Colima** needs a host route to reach the cluster. `up` provisions what it can, then halts and prints `Run 'windsor configure network' (sudo), then re-run 'windsor up'.` Run it and re-run `up` to finish the install.
- **Docker Desktop** only needs DNS. `up` completes, then prints `configure network` as a follow-up so `*.<domain>` resolves from your browser. Run it once; there's no re-run.

Writing the DNS resolver entry needs elevation either way, so that step applies to every local runtime. Once it's configured, later `up` runs skip it. Use `--dry-run` to preview and `--revert` to remove what it installed.

`down` stops the VM and clears local artifacts. It does not touch live cloud resources; run `destroy` first for that.

## A cloud or metal context

Staging, production, and any other deployment context has no VM. The first run uses `bootstrap`; later reconciles use `apply`:

```bash
windsor init staging
windsor set context staging
windsor bootstrap               # first run: handles backend, migrates state, waits for kustomizations
# ... later reconciles ...
windsor apply --wait
# ... and tear down ...
windsor destroy --confirm=staging
```

`apply` runs the Terraform components and installs the Flux blueprint, the same work `up` does for a workstation but without managing a VM. It supports targeted runs:

```bash
windsor apply terraform cluster        # one terraform component
windsor apply kustomize observability  # one Flux kustomization
```

Use `bootstrap` on the first run. It handles a chicken-and-egg case with the Terraform backend, described in [Under the hood](#under-the-hood).

## Inspect before you apply

`windsor plan` previews changes without applying them. With no argument it prints a summary across all components; with a name it streams the full plan for that component:

```bash
windsor plan                    # summary across all components
windsor plan terraform cluster  # full plan for one component
```

To inspect the composition itself, render it with `windsor show` or trace a value with `windsor explain`. See [Inspecting](../blueprints/inspecting.md).

## Tear down

`destroy` removes live infrastructure: every Flux kustomization, then every Terraform component in reverse-dependency order. Before it touches anything it shows a destroy plan (the Terraform resources it will remove and the live Flux inventory queried from the cluster) and waits for confirmation.

Confirmation is always required. Type the context name (layer-wide) or component name (targeted) at the prompt, or pass `--confirm=<expected>` for CI. The value must match the prompt token exactly, or the run aborts. There is no `--force`.

A workstation context needs `destroy` then `down` for a full teardown. A cloud or metal context has no VM, so `destroy` is the whole teardown:

```bash
windsor destroy --confirm=local
windsor down
```

## Under the hood

`bootstrap` handles the case where the remote Terraform backend, an S3 bucket or DynamoDB table, is itself created by Terraform. It applies the `backend` component against local state, migrates state to the configured backend, then runs the rest of `apply`. With no `backend` component declared, `bootstrap` is the same as `apply`.

`plan` sorts its output destructive-first. The summary renders per-component rows with affected resources indented underneath, and a single replace shows as `±1` rather than `+1 -1`. Add `--summary` for the compact table, `--json` for machine-readable output in CI, or `--no-color` to disable color.

### Safety and concurrency

`destroy` has two safety behaviors:

- If a Terraform resource carries `lifecycle { prevent_destroy = true }`, `destroy` names it up front and warns the run may halt partway through. It does not override the protection; remove the lifecycle block in HCL to actually destroy.
- By default `destroy` aborts on the first component failure. `--continue` keeps going, collects failures, and prints a one-line summary. It is layer-wide only, and is refused with a component argument. When a non-tier component is left un-destroyed, the backend tier is deferred so the state store isn't removed out from under components that still depend on it. Rerun to converge.

A per-context lock guards concurrent runs. `up`, `apply`, `bootstrap`, `destroy`, and any `plan` that touches Terraform take a single-writer stack lock at `.windsor/contexts/<context>/.stacklock` before they run. A second `windsor` command on the same context waits up to 5 minutes for the lock, then fails and names the holder (`user@host`, PID, operation). Different contexts never contend, and a read-only `plan kustomize` does not lock. Terraform's own state lock follows `terraform.lock.timeout` (default `5m`), applied as `-lock-timeout` to every state-mutating Terraform command, so contended state waits rather than failing immediately.

## Reference

| Group | Command | What it does |
|---|---|---|
| Scaffold | [`init`](https://www.windsorcli.dev/reference/cli/commands/init) | Creates the context, writes `windsor.yaml`, marks the directory trusted. |
| Workstation | [`up`](https://www.windsorcli.dev/reference/cli/commands/up) / [`down`](https://www.windsorcli.dev/reference/cli/commands/down) | Starts/stops the local VM and container runtime. Workstation contexts only. |
| First-run | [`bootstrap`](https://www.windsorcli.dev/reference/cli/commands/bootstrap) | End-to-end install for non-workstation contexts. Two-phase apply when a `backend` component is in play. |
| Install | [`apply`](https://www.windsorcli.dev/reference/cli/commands/apply) | Runs Terraform components, then installs the Flux blueprint. |
| Inspect | [`plan`](https://www.windsorcli.dev/reference/cli/commands/plan) / [`show`](https://www.windsorcli.dev/reference/cli/commands/show) / [`explain`](https://www.windsorcli.dev/reference/cli/commands/explain) | Previews changes, prints rendered resources, traces values. |
| Tear down | [`destroy`](https://www.windsorcli.dev/reference/cli/commands/destroy) | Destroys live infrastructure (Terraform + Flux). |

- [Contexts](overview.md) — workstation vs non-workstation, switching contexts
- [Workstation overview](../workstation/overview.md) — VM driver options and topology
