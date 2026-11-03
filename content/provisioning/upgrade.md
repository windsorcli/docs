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
windsor upgrade --source core=oci://ghcr.io/windsorcli/core:v0.9.0
```

`upgrade` won't move a source to an older version unless you pass `--allow-downgrade`. A downgrade reverts infrastructure only. It does not undo changes that an add-on already made to application data, such as a migrated database schema.

Before it moves anything, `upgrade` checks the target blueprint's `cliVersion` constraint, set in its `metadata.yaml`, against your installed CLI. It fails if the CLI is too old. See [CLI version compatibility](../blueprints/sharing.md#cli-version-compatibility).

## Talos nodes

The [`windsor upgrade node`](https://www.windsorcli.dev/reference/cli/commands/upgrade-node) and [`windsor upgrade cluster`](https://www.windsorcli.dev/reference/cli/commands/upgrade-cluster) commands exist so that Terraform can call them, as a workaround for the [Talos Terraform provider](https://github.com/siderolabs/terraform-provider-talos) having no resource that upgrades a node. `windsor upgrade node` sends the upgrade to one node, waits for the reboot, and checks that the node is healthy, so a node upgrade can run as an ordinary Terraform step.

If you call it from your own Terraform, set [`parallelism: 1`](https://www.windsorcli.dev/reference/cli/blueprint) on the component. Windsor passes it to Terraform as [`-parallelism=1`](https://developer.hashicorp.com/terraform/cli/commands/apply), so the nodes upgrade one at a time. For a more managed experience, consider [Omni](https://www.siderolabs.com/omni/).

`core` does this in its [`cluster/talos/extensions`](https://github.com/windsorcli/core/blob/main/terraform/cluster/talos/extensions/main.tf) module, which runs `windsor upgrade node` on each node, controlplanes first and then workers. Clusters that need Talos extensions, such as for Longhorn or Mayastor storage, include it. It runs whenever the Talos version or the extension list changes, so a `windsor upgrade` that moves `core` to a release with a newer Talos version upgrades those nodes during the Terraform apply.

You don't normally run these commands yourself. To upgrade nodes by hand, [`talosctl upgrade`](https://docs.siderolabs.com/talos/latest/configure-your-talos-cluster/lifecycle-management/upgrading-talos) does the same job.

## Upgrade core to v0.9.0

`core` v0.9.0 sets `cliVersion: ">=0.10.0"`, so `windsor upgrade` stops on an older CLI. Install Windsor CLI v0.10.0 or later first. Then move the source:

```bash
windsor upgrade --source core=oci://ghcr.io/windsorcli/core:v0.9.0
```

Some changes in this release alter a running context. Read each subsection that applies to your contexts before you confirm the upgrade.

### The cluster CA is always installed

Every context runs the `pki/ca` Terraform component and installs trust-manager. The `private` ClusterIssuer always signs with the cluster CA, and `core` ignores `pki.enabled`.

Outside dev mode, a context with `pki.enabled` unset or `false` had a self-signed `private` issuer. On upgrade, the issuer changes to the cluster CA, and cert-manager reissues each certificate from that issuer.

If you supply your own CA, move `pki.private_ca.cert` and `pki.private_ca.key` to `pki.ca.cert` and `pki.ca.key`. `core` reads `pki.private_ca` only when `pki.ca` is not set.

### Kubernetes backend state moves to `system-terraform`

On the `kubernetes` backend, the state Secrets move from the `default` namespace to `system-terraform`. A new `backend/kubernetes` component creates the namespace. The upgrade's apply moves the state of each component and prints one line for each move. The old Secrets stay in `default`. Delete them after you confirm that the upgrade is complete. [State backend](state-backend.md#kubernetes-backend) has the details.

The platform facets no longer set `backend: cluster`. If a context's `blueprint.yaml` still has `backend: cluster`, Windsor uses the value from the facets and prints a warning. Remove the line.

### The Talos VIP is opt-in

`cluster.vip` controls the Talos shared control-plane VIP on Incus, Proxmox, vSphere, and Hyper-V. It defaults to `false`. Earlier releases configured the VIP on vSphere and Hyper-V with no setting. On those platforms, the first apply after the upgrade removes the VIP. To keep it, set `cluster.vip: true`. The host in `cluster.endpoint` becomes the VIP. It must be an IPv4 address that no control plane uses, on the same layer-2 segment as the control planes.

### DHCP control planes require `cluster.endpoint`

On Hyper-V, Proxmox, and vSphere, a context with `network.dhcp: true` and more than one control plane must set `cluster.endpoint`. Without it, composition fails with this message:

```text
Several DHCP control planes share the API address in cluster.endpoint; pick one outside the DHCP scope.
```

Set `cluster.endpoint` to an address outside the DHCP scope.

### The ingress add-on is removed

`core` no longer contains `kustomize/ingress/`, the NGINX ingress add-on. No `core` facet used it. Envoy Gateway, in the `gateway` system, handles ingress traffic. Remove each `kustomize:` entry in your blueprints that refers to a `core` path under `ingress`.

`core` also removes the top-level `kustomization.yaml` files in `gateway/`, `identity/`, and `object-store/`. Each `core` system reconciles from its own `install` and `resources` paths. A `kustomize:` entry that refers to the top of one of these directories must refer to one of those paths instead. [Flux systems](../blueprints/flux-systems.md) explains the two paths.

### Context IDs fit each resource name

Windsor CLI v0.10.0 accepts a context `id` of 1 to 63 characters, the DNS label limit, and rejects a longer one. Many cloud resource names have a shorter limit. When the `id` is too long for a name, `core` truncates the `id` and adds the first 6 hex characters of its SHA-256 hash. An `id` that fits keeps the name unchanged, so no existing resource gets a new name. The `database/azure-postgres` module no longer rejects an `id` longer than 22 characters.

### The identity contract exposes the administrator group

`identity.admin_group` sets the group whose members are administrators in Grafana and, in dev mode, in the cluster. It defaults to `platform-admins`, the group name in earlier releases, so you change nothing on upgrade. With the hosted Keycloak, `core` creates the group in the realm. With an external OIDC provider, the provider must send the group in its `groups` claim. Facets read the value as `identity_effective.admin_group`.

## See also

- [Overview](overview.md): where `upgrade` fits among the other commands
- [Destroy](destroy.md): tearing a context down instead of moving it forward
