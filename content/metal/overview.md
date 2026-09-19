---
title: Overview
description: What platform metal means in Windsor today — no compute module, and a self-hosted Talos control plane on hardware that's already running.
---

Metal has no compute module. Docker, Hyper-V, and Incus provision the containers or VMs Talos runs on; AWS and Azure provision a managed control plane. Metal does neither — the nodes are already up before Windsor sees them.

```yaml
platform: metal
cluster:
  driver: talos
  endpoint: https://10.5.0.1:6443
  controlplanes:
    count: 1
    schedulable: true
  workers:
    count: 0
```

`cluster.driver` defaults to `talos` for any platform other than `aws` or `azure`. The `cluster/talos` module reaches the nodes named in `cluster.endpoint` through the Talos API and writes a kubeconfig — the same mechanism Hyper-V, vSphere, and Hetzner use once their own compute module hands off provisioned nodes. On metal that hand-off is skipped: point `cluster.endpoint` at hardware that's already running Talos.

Getting a physical machine to that state — imaging it, PXE-booting it, or building an installer with [Image Factory](https://factory.talos.dev) — is outside Windsor's scope. See the [Talos project](https://github.com/siderolabs/talos) for that step.

Like Hetzner, Hyper-V, and vSphere, there's no managed control plane, so `cluster.oidc.enabled` works for `kubectl` SSO — see [Identity](https://www.windsorcli.dev/catalog/core/guides/identity/keycloak). The Terraform backend defaults to in-cluster storage (each component's state as a Secret), unless `windsor.yaml` sets something else.

## See also

- [Raspberry Pi](raspberry-pi.md) — a Pi is a metal target too
- [terraform/cluster/talos](https://github.com/windsorcli/core/tree/main/terraform/cluster/talos) on GitHub — every `cluster.*` field
- [Local](../workstation/overview.md), [Virtual](../virtual/hyperv.md), [Cloud](../cloud/aws.md) — the other provisioning targets
