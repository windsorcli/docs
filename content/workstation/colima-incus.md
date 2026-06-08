---
title: Colima + Incus
description: Run Windsor locally with Colima and Incus (LXC).
---

You can run Windsor's local workstation using [Colima](https://github.com/abiosoft/colima) with [Incus](https://linuxcontainers.org/incus/) (LXC) as the container runtime instead of Docker. This option is useful when you want full virtualization with an LXC-based stack.

## Comparison with other runtimes

| Feature | Colima + Incus | Colima + Docker | Docker Desktop |
|---------|----------------|-----------------|-----------------|
| DNS | Routes to service IPs | Routes to service IPs | Routes to localhost |
| Docker registries | Full registry support (LXC/Incus image semantics) | Full registry support | Full registry support (local: registry.test:5002) |
| Local Git | Full support | Full support | Full support |
| Kubernetes node type | VM host nodes | Container host nodes | Container host nodes |
| Device emulation | Block devices | Filesystem only | Filesystem only |
| Network | Addressable IP range, L2 LB | Addressable IP range, L2 LB | Localhost, port-forward, NodePort |

In all cases, full registry support means local **registry caches (mirrors)** of major registries (GCR, GHCR, Quay, Docker Hub, `registry.k8s.io`). Configure mirrors in `windsor.yaml`; see [Colima + Docker — Registries](/workstation/colima-docker#registries) for details (endpoints differ by runtime).

## When to use

- You prefer Incus/LXC over Docker for local workloads.
- You need full virtualization (like [Colima + Docker](/workstation/colima-docker)) with a different runtime.

## Setup

Install Colima and Incus, then (Apple silicon with nested virtualization, Linux):

```bash
windsor init local --vm-driver colima-incus
windsor up
```

Exact install steps depend on your Colima and Windsor version; refer to the [CLI repo](https://github.com/windsorcli/cli) and [Colima documentation](https://github.com/abiosoft/colima). See [First project — VM driver](/getting-started/first-project) for all drivers.

## Differences from Colima + Docker

Runtime and container semantics differ (LXC vs Docker). Registry usage, build ID, and Kubernetes behavior may vary. For the most common local-dev workflow (Docker images, local registry, Kubernetes), [Colima + Docker](/workstation/colima-docker) is the primary supported path.
