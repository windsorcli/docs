---
title: Troubleshooting
description: Common Windsor failure modes and their fixes — lifecycle, workstation networking, state backends, environment injection, and blueprints.
---

Common failure modes, grouped by where they show up. Each entry lists the symptom, the cause, and the fix. For the command model these reference, see [Lifecycle](/contexts/lifecycle).

## Lifecycle and commands

**`windsor up` prints a hint and does nothing.**
The current context has no workstation. `up` is workstation-only. Use [`bootstrap`](/contexts/lifecycle) for a first run on a cloud or metal context, or `apply` for day-two reconciles.

**`up` finishes by printing a `windsor configure network` command.**
Host networking and DNS need elevation, which `up` defers rather than prompting for sudo mid-run. Run `windsor configure network` once (it prompts for sudo); use `--dry-run` to preview or `--revert` to undo.

**`destroy` aborts with a confirmation error.**
The `--confirm` value (or what you typed at the prompt) must match the prompt token exactly — the context name for a layer-wide destroy, or the component name for a targeted one. A mismatch aborts. There is no `--force`.

**`destroy` warns about `prevent_destroy` and may stop partway.**
A Terraform resource carries `lifecycle { prevent_destroy = true }`. Windsor warns but does not override it. To actually remove the resource, delete the lifecycle block in the module's HCL, then re-run.

**A command waits up to five minutes, then fails naming a lock holder.**
Another `windsor` command holds the per-context [stack lock](/contexts/lifecycle#safety-and-concurrency). Wait for it, or stop the other process. If a process was killed mid-run, the lock clears on the next acquire; the named holder may be a stale PID until then.

## Workstation and networking

**`*.test` (or your `dns.domain`) doesn't resolve locally.**
On VM-backed runtimes (Colima), cluster reachability needs a host route and a resolver entry that `windsor configure network` installs. Run it, then test with `dig @dns.test registry.test`. Docker Desktop routes DNS to localhost and usually doesn't need this step.

**Cluster nodes are unreachable after `up`.**
The host route from `configure network` is missing or was reverted. Re-run `windsor configure network`; confirm it reports the route and DNS entry.

## Deploy and state backend

**A cloud deploy hard-errors before the confirm prompt about a missing backend.**
Remote state requires the blueprint to declare which Terraform component terminates the backend tier. Use a `platform` that sets one (`--platform aws`/`azure`), or declare a `backend` component. See [Terraform — State backend](/blueprints/terraform#state-backend).

**`bootstrap` fails during the first (backend) stage.**
Credentials or region aren't resolving. Confirm the provider CLI is authenticated (for AWS, `aws sts get-caller-identity`) and the region is set. The backend stack runs first, so a credential error stops everything downstream. See [AWS](/deployment/aws).

**State seems out of sync after an interrupted `bootstrap`.**
`bootstrap` migrates state from local to remote in stages and is safe to re-run; a follow-up `up`/`apply` repairs a half-migrated component. Re-run `windsor bootstrap --wait`.

## Environment and trust

**`windsor env` prints nothing and tools can't find the cluster.**
The current directory isn't trusted, so env injection stays silent. `windsor init` trusts the project root; otherwise the folder must be recorded in `~/.config/windsor/.trusted`. See [Trusted folders](/contexts/trusted-folders).

**`kubectl` targets the wrong cluster.**
The shell hook isn't installed, so `KUBECONFIG` isn't tracking the context. Install it with `windsor hook <shell>` (see [Environment injection](/contexts/environment-injection)), or prefix one-off commands with `windsor exec --`.

## Blueprints and schema

**Schema validation fails citing the `windsorcli.dev/draft/2026-02/schema` dialect.**
That dialect was removed in v0.9.0. Replace `$schema` in your `schema.yaml` with `https://json-schema.org/draft/2020-12/schema`. See [Schema](/blueprints/schema).

**A required value error stops a command (for example, `aws.region`).**
A facet's `requires` block flags a missing value. Set it in the context's `values.yaml`. Run `windsor explain <path>` to trace where a value resolves from.

**An OCI blueprint pull fails with an auth error.**
Private registries use your Docker credential chain. Run `docker login <registry>` and retry. If a stale cached artifact is the problem, re-run with `--no-cache`. See [Sharing blueprints](/blueprints/sharing#caching-and-private-registries).

**A tool is missing or too old.**
Run `windsor check` to validate the toolchain; it names what's missing or needs upgrading.

## Where to next

- [Lifecycle](/contexts/lifecycle) — the command model and safety behaviors
- [Environment injection](/contexts/environment-injection) — the shell hook and trust gate
- [Terraform](/blueprints/terraform) — state backends and the bootstrap flow
