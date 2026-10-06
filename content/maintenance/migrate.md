---
title: Migrate
description: How Windsor recovers Terraform state left behind by an interrupted bootstrap or a renamed component.
---

Windsor looks for Terraform state stranded by an interrupted bootstrap or a renamed component. It recovers the first automatically on `up` and on a layer-wide `apply` with a remote backend, and only warns about the second, because a renamed component looks the same as a decommissioned one.

## An interrupted bootstrap

`bootstrap` moves a `backend` component's state from local to the configured remote backend in two phases. If a run gets interrupted between them, the component is left with local state that never made it to the remote backend.

The next `up` or layer-wide `apply` that touches Terraform recovers this automatically, before anything else runs: for each component still declared in the blueprint, if it has local state and the configured backend has none yet for it, Windsor resets the backend pointer to local, runs `terraform init -migrate-state -force-copy` against the real backend, then removes the local state file. There is no confirmation prompt: the recovery only fires when the remote side is confirmed empty for that component, so nothing gets overwritten.

A backend probe failure (bad credentials, no connectivity, the backend storage itself missing) aborts the whole sweep. `-force-copy` overwrites the destination unconditionally, so a transient probe failure can't be treated as "no remote state": that assumption could silently replace good remote state with a stale local copy. Resolve the underlying failure and retry.

## A renamed component

Renaming a component in `blueprint.yaml` gives it a new ID. Its old state stays on disk under the old ID, and Windsor can't tell that apart from a component you meant to decommission, since an ID that's gone from the blueprint looks the same either way. Because of that, [`windsor up`](https://www.windsorcli.dev/reference/cli/commands/up), [`windsor apply`](https://www.windsorcli.dev/reference/cli/commands/apply), and [`windsor destroy`](https://www.windsorcli.dev/reference/cli/commands/destroy) only warn about it:

```text
warning: found local terraform state for "<old-id>", which is no longer in the
blueprint; state was not migrated automatically — if this component was
renamed, re-add it under this ID to migrate its state, or reconcile it
manually
```

Windsor never force-copies orphaned state into the shared backend unattended: publishing it under an ID nothing will ever reference again would pollute the backend permanently, with no way to tell later whether that was ever intended. Two ways to resolve it:

- **It was a rename.** Add the component back under its old ID (even temporarily), and the next `up` or layer-wide `apply` migrates it through the interrupted-bootstrap path above, since the ID is declared again.
- **It was a real decommission.** Reconcile the local state file manually; Windsor has nothing to act on automatically.

## See also

- [Lifecycle](../provisioning/overview.md): where `up` and `apply` fit among the other commands
- [State backend](../provisioning/state-backend.md): configuring the backend this migrates state into
- [Destroy](../provisioning/destroy.md): retiring a component's infrastructure instead of moving its state
