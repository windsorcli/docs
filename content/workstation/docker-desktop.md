---
title: Docker Desktop
description: Run Windsor locally with Docker Desktop.
---

[Docker Desktop](https://docs.docker.com/desktop/) runs on Linux, macOS, and Windows. Windsor supports it as a lightweight container-based option; not all features available with full virtualization (for example, Colima) are supported.

## Differences from full virtualization

| Feature | Docker Desktop (lightweight) |
|---------|------------------------------|
| DNS | Routes to localhost |
| Docker registries | Full registry support (local: registry.test:5002) |
| Local Git | Full support |
| Kubernetes node type | Container host nodes |
| Device emulation | Filesystem only |
| Network | Localhost, port-forward, NodePort |

## Setup

After [installing the CLI](https://www.windsorcli.dev/cli/installation) and [starting a project](../getting-started/first-project.md), ensure Docker Desktop is running. Then:

```bash
windsor init local --vm-driver docker-desktop
windsor up
windsor configure network        # activates DNS — needs elevation (see DNS)
```

On Linux, `docker` is the default when `--vm-driver` is omitted; use `docker-desktop` if you run Docker Desktop there. See [First project — VM driver](../getting-started/first-project.md) for all drivers.

## DNS

`up` does not prompt for elevation, so it defers DNS setup and prints a `windsor configure network` follow-up. That command points the reserved local domain (default `test`) at the cluster DNS — with Docker Desktop it resolves to 127.0.0.1. **Writing the rule always needs elevated privileges**, and the mechanism differs by OS:

- **macOS / Linux:** run `windsor configure network` from a normal shell; it prompts for sudo per privileged step (cached after the first prompt) and writes `/etc/resolver/<domain>`.
- **Windows:** the whole process must be elevated — open **PowerShell as Administrator** (right-click → Run as Administrator), `cd` to the project, then run `windsor configure network`. From a normal shell it fails fast with a "must be run from an Administrator PowerShell" error. It installs a per-domain **NRPT rule** rather than a resolver file; if a Group Policy manages NRPT it can shadow the rule, and the command warns when that happens (see [Troubleshooting](../troubleshooting/overview.md#workstation-and-networking)).

Use `--dry-run` to preview or `--revert` to remove it. Unlike Colima, Docker Desktop needs no host route — only the DNS rule, so `up` completes without halting. Test resolution with:

- **Windows:** `nslookup registry.test dns.test`
- **macOS / Linux:** `dig @dns.test registry.test`

## Local registry

Full registry support means local **registry caches (mirrors)** of major registries (GCR, GHCR, Quay, Docker Hub, `registry.k8s.io`); the generic local registry is at `http://registry.test:5002`. Use `REGISTRY_URL` (set automatically). Push images:

```bash
docker build -t my-image:latest .
docker tag my-image:latest ${REGISTRY_URL}/my-image:latest
docker push ${REGISTRY_URL}/my-image:latest
```

## When to use Colima instead

For full virtualization, addressable IP ranges, and full local Git clone support (for example, `git clone http://local@git.test/git/my-project`), use [Colima + Docker](colima-docker.md) or [Colima + Incus](colima-incus.md).
