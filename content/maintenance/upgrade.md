---
title: Upgrade
description: Moving a running context to a newer blueprint version and reconciling the result.
---

`windsor upgrade` moves a running context to a newer blueprint version and reconciles the result, in one step:

```bash
windsor upgrade --yes
```

With no flags, it moves every declared OCI source to its latest stable tag. It then applies Terraform, installs the updated Flux blueprint, waits for it to become ready, and prunes any kustomization the new blueprint no longer declares. `--yes` is required whenever the run would prune something; without it, `upgrade` stops and shows what it would remove first. `apply --prune` does the same pruning on a plain apply, for that behavior without also moving source versions.

Move one source instead of all of them with `--source name=url`, which persists to `blueprint.yaml`:

```bash
windsor upgrade --source core=oci://ghcr.io/windsorcli/core:v0.8.0 --yes
```

`upgrade` refuses to move a source backward by default — a blueprint author raises a version floor for a reason. Pass `--allow-downgrade` to override it. This only reverts infrastructure declaratively; it does not undo changes an add-on already made to application data (a migrated database schema, for example).

Before moving anything, `upgrade` checks the target blueprint's own `cliVersion` constraint (set in its `metadata.yaml`) against your installed CLI, and fails with an explanatory error if your CLI is too old. See [CLI version compatibility](../blueprints/sharing.md#cli-version-compatibility).

## Talos nodes

Blueprint upgrades don't touch the Talos nodes themselves — that's a separate step, split into two commands depending on how much parallelism you want:

```bash
# Roll every controlplane node at once; returns once requests are accepted
windsor upgrade cluster --nodes=10.0.0.5,10.0.0.6,10.0.0.7 \
  --image=ghcr.io/siderolabs/installer:v1.13.0

# Roll one node at a time, blocking until each rejoins healthy
windsor upgrade node --node=10.0.0.5 \
  --image=ghcr.io/siderolabs/installer:v1.13.0
```

`upgrade cluster` triggers the upgrade on every named node in parallel and returns as soon as the requests are accepted. Nodes reboot asynchronously, so follow up with `windsor check node-health --wait-for-reboot` to confirm they came back. `upgrade node` is the rolling-upgrade `primitive`: it waits for the single node to reboot and pass a health check before returning. A script can call it once per node and get a real go/no-go between each one. Both take `--reboot-mode=powercycle` for platforms (commonly nested virtualization) where the default fast `kexec` reboot doesn't reliably register as an offline transition.

## See also

- [Command model](../provisioning/workflow.md) — where `upgrade` fits among the other commands
- [Destroy](destroy.md) — the other maintenance action on a running context
