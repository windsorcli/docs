---
title: Upgrade
description: Moving a running context to newer blueprint versions, and upgrading Talos nodes.
---

[`windsor upgrade`](https://www.windsorcli.dev/reference/cli/commands/upgrade) moves a running context to newer versions of its blueprint sources and applies the result.

```bash
windsor upgrade
```

A source is an entry under `sources:` in `blueprint.yaml`. It may be an OCI blueprint artifact or a Git repository that supplies Terraform modules and kustomize bases. A given context may inherit from several sources. Running `windsor init` creates a `blueprint.yaml` file that references a single source, `core`. Passing a `--blueprint` value sets an explicit source. See the [blueprint reference](https://www.windsorcli.dev/reference/cli/blueprint).

By default, `upgrade` moves every declared OCI source to its latest stable tag. It prints what will change, meaning each source's current and target version and the kustomizations it would prune, and asks you to confirm. It then applies Terraform, installs the updated Flux blueprint, waits until it is ready, and prunes kustomizations that the new blueprint no longer declares.

Pass `--yes` to skip the prompt, for scripts and CI. With no terminal and no `--yes`, `upgrade` exits with an error.

To see what an upgrade would do without running it, answer no at the prompt. `upgrade` prints the plan, which lists the source moves and the kustomizations it would prune, and leaves `blueprint.yaml` unchanged. [`windsor plan`](https://www.windsorcli.dev/reference/cli/commands/plan) previews Terraform and Flux changes.

`upgrade` prunes only the kustomizations in the plan you confirmed. To prune any others, or to prune without moving versions, use `apply --prune`.

To upgrade only one source, pass `--source name=url`. Windsor saves the new URL to `blueprint.yaml`:

```bash
windsor upgrade --source core=oci://ghcr.io/windsorcli/core:v0.8.0
```

`upgrade` won't move a source to an older version unless you pass `--allow-downgrade`. A downgrade reverts infrastructure only. It does not undo changes that an add-on already made to application data, such as a migrated database schema.

Before it moves anything, `upgrade` checks the target blueprint's `cliVersion` constraint, set in its `metadata.yaml`, against your installed CLI. It fails if the CLI is too old. See [CLI version compatibility](../blueprints/sharing.md#cli-version-compatibility).

## Talos nodes

The [`windsor upgrade node`](https://www.windsorcli.dev/reference/cli/commands/upgrade-node) and [`windsor upgrade cluster`](https://www.windsorcli.dev/reference/cli/commands/upgrade-cluster) commands exist so that Terraform can call them, as a workaround for the [Talos Terraform provider](https://github.com/siderolabs/terraform-provider-talos) having no resource that upgrades a node. `windsor upgrade node` sends the upgrade to one node, waits for the reboot, and checks that the node is healthy, so a node upgrade can run as an ordinary Terraform step.

If you call it from your own Terraform, set [`parallelism: 1`](https://www.windsorcli.dev/reference/cli/blueprint) on the component. Windsor passes it to Terraform as [`-parallelism=1`](https://developer.hashicorp.com/terraform/cli/commands/apply), so the nodes upgrade one at a time. For a more managed experience, consider [Omni](https://www.siderolabs.com/omni/).

`core` does this in its [`cluster/talos/extensions`](https://github.com/windsorcli/core/blob/main/terraform/cluster/talos/extensions/main.tf) module, which runs `windsor upgrade node` on each node, controlplanes first and then workers. Clusters that need Talos extensions, such as for Longhorn or Mayastor storage, include it. It runs whenever the Talos version or the extension list changes, so a `windsor upgrade` that moves `core` to a release with a newer Talos version upgrades those nodes during the Terraform apply.

You don't normally run these commands yourself. To upgrade nodes by hand, [`talosctl upgrade`](https://docs.siderolabs.com/talos/latest/configure-your-talos-cluster/lifecycle-management/upgrading-talos) does the same job.

## See also

- [Overview](overview.md): where `upgrade` fits among the other commands
- [Destroy](destroy.md): tearing a context down instead of moving it forward
