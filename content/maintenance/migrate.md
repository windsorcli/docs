---
title: Migrate
description: How Windsor recovers Terraform state left behind by an interrupted bootstrap or a renamed component.
---

An interrupted bootstrap or a renamed component can leave Terraform state stranded on your machine. Windsor checks for both cases. It recovers state from an interrupted bootstrap on `up`, and on a layer-wide `apply` with a remote backend. For a renamed component it only warns, because a renamed component looks the same as a decommissioned one.

## An interrupted bootstrap

`bootstrap` moves a `backend` component's state from local to the configured remote backend in two phases. If a run is interrupted between them, the component is left with local state that never reached the remote backend.

The next `up`, or the next layer-wide `apply` that touches Terraform, recovers this state before anything else runs. Windsor checks each component that the blueprint still declares. If the component has local state and the configured backend has none for it, Windsor resets the backend pointer to local and runs `terraform init -migrate-state -force-copy` against the real backend. Then it removes the local state file. There is no confirmation prompt. The migration runs only when the remote side has no state for that component, so it never overwrites anything.

A backend probe failure, such as bad credentials, no connectivity, or missing backend storage, stops the whole recovery. Windsor can't treat a failed probe as "no remote state", because `-force-copy` overwrites the destination unconditionally and could replace good remote state with a stale local copy. Fix the failure and run the command again.

## A renamed component

Renaming a component in `blueprint.yaml` gives it a new ID. Its old state stays on disk under the old ID, and Windsor can't tell that apart from a component you meant to decommission, since an ID that's gone from the blueprint looks the same either way. Because of that, [`windsor up`](https://www.windsorcli.dev/reference/cli/commands/up), [`windsor apply`](https://www.windsorcli.dev/reference/cli/commands/apply), and [`windsor destroy`](https://www.windsorcli.dev/reference/cli/commands/destroy) only print this warning.

```text
warning: found local terraform state for "<old-id>", which is no longer in the
blueprint; state was not migrated automatically — if this component was
renamed, re-add it under this ID to migrate its state, or reconcile it
manually
```

Windsor never copies orphaned state into the shared backend unattended. Under an ID that nothing references, the state would stay in the backend permanently, and no one could tell later whether that was intended. How you resolve the warning depends on what happened to the component.

- If you renamed it, add the component back under its old ID, even temporarily. Because the ID is declared again, the next `up` or layer-wide `apply` migrates its state, as [An interrupted bootstrap](#an-interrupted-bootstrap) describes.
- If you decommissioned it, reconcile the local state file by hand. Windsor has nothing to act on.

## See also

- [Lifecycle](../provisioning/overview.md): where `up` and `apply` fit among the other commands
- [State backend](../provisioning/state-backend.md): configuring the backend this migrates state into
- [Destroy](../provisioning/destroy.md): retiring a component's infrastructure instead of moving its state
