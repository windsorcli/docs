---
title: Destroy
description: Removing live infrastructure safely, and the safety and locking behaviors that guard a destroy run.
---

`windsor destroy` removes a context's live infrastructure: every Flux kustomization first, then every Terraform component in reverse-dependency order. It shows what it will remove and waits for you to type the context name before touching anything.

## Tear down

The destroy plan lists the Terraform resources to be removed and the live Flux inventory queried from the cluster.

Confirmation is always required. Type the context name (layer-wide) or component name (targeted) at the prompt, or pass `--confirm=<expected>` for CI. The value must match the prompt token exactly, or the run aborts. There is no `--force`.

A workstation context needs `destroy` then `down` for a full teardown. A cloud or metal context has no VM, so `destroy` is the whole teardown:

```bash
windsor destroy --confirm=local
windsor down
```

## Safety and concurrency

`destroy` has two safety behaviors:

- If a Terraform resource carries `lifecycle { prevent_destroy = true }`, `destroy` names it up front and warns the run may halt partway through. It does not override the protection; remove the lifecycle block in HCL to actually destroy.
- By default `destroy` aborts on the first component failure. `--continue` keeps going, collects failures, and prints a one-line summary. It is layer-wide only; Windsor refuses it when given a component argument. When a non-tier component stays un-destroyed or a Flux kustomization fails to delete, `destroy` defers the backend tier so it doesn't remove the state store out from under components that still depend on it. Rerun to converge.

A per-context lock guards concurrent runs. `up`, `apply`, `bootstrap`, `upgrade`, `destroy`, and any `plan` that touches Terraform take a single-writer stack lock at `.windsor/contexts/<context>/.stacklock` before they run. A second `windsor` command on the same context fails immediately and names the holder (`user@host`, PID, operation). Pass `--lock-timeout` to wait up to that duration before failing instead. See [Global flags](https://www.windsorcli.dev/reference/cli/global-flags). Different contexts never contend, and a read-only `plan kustomize` does not lock. Terraform's own state lock follows `terraform.lock.timeout` (default `5m`), applied as `-lock-timeout` to every state-mutating Terraform command, so contended state waits rather than failing immediately.

A holder that dies (CI cancellation, an OOM, a crash) normally releases the lock with the process. An orphaned child process that inherited it can keep it held, so later commands wait out the timeout and then fail. `windsor unlock` force-clears it after you type the context name; `--force` skips that prompt. It does not check whether the holder is still alive, so only run it once you're sure no other `windsor` process is using the context.

## See also

- [Command model](../provisioning/workflow.md): where `destroy` fits among the other commands
- [Upgrade](upgrade.md): moving a context forward instead of tearing it down
