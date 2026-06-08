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

After [installing the CLI](/cli/installation) and [starting a project](/getting-started/first-project), ensure Docker Desktop is running. Then:

```bash
windsor init local --vm-driver docker-desktop
windsor up
```

On Linux, `docker` is the default when `--vm-driver` is omitted; use `docker-desktop` if you run Docker Desktop there. See [First project — VM driver](/getting-started/first-project) for all drivers.

## DNS

The CLI configures your resolver so the reserved local domain (default `test`) points at a local CoreDNS container. With Docker Desktop, DNS typically resolves to 127.0.0.1. Test with:

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

For full virtualization, addressable IP ranges, and full local Git clone support (for example, `git clone http://local@git.test/git/my-project`), use [Colima + Docker](/workstation/colima-docker) or [Colima + Incus](/workstation/colima-incus).
