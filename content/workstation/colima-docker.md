---
title: Colima + Docker
description: Full local virtualization with Colima and Docker.
---

On macOS and Linux, [Colima](https://github.com/abiosoft/colima) wraps [Lima](https://github.com/lima-vm/lima) to give full virtualization on the platform's hypervisor. The result is a local environment that closely matches production: DNS to service IPs, full registry support, and a local Git server you can clone from another folder.

## Comparison with Docker Desktop

| Feature | Colima (full virtualization) | Docker Desktop |
|---------|------------------------------|-----------------|
| DNS | Routes to service IPs | Routes to localhost |
| Docker registries | Full registry support | Full registry support (local: registry.test:5002) |
| Local Git | Full support | Full support |
| Kubernetes node type | Container host nodes | Container host nodes |
| Device emulation | Filesystem only | Filesystem only |
| Network | Addressable IP range, L2 LB | Localhost, port-forward, NodePort |

## Prerequisites

Complete [First project](/getting-started/first-project). Then (Apple silicon, Linux):

```bash
windsor init local --vm-driver colima
windsor up                       # halts: "Run 'windsor configure network', then re-run 'windsor up'"
windsor configure network        # host route + DNS (prompts for sudo)
windsor up                       # re-run to install the blueprint
```

Colima is VM-backed, so cluster reachability needs a host route in addition to the `*.test` DNS resolver entry. Because both need elevation and `up` won't prompt for sudo, the first `up` provisions what it can and then **halts**. Run `configure network` to install the host route and resolver entry, then re-run `up` to finish the install. Subsequent `up` runs don't repeat the step. Use `--dry-run` to preview or `--revert` to remove it.

See [First project — VM driver](/getting-started/first-project) for other drivers.

## DNS

The CLI configures your resolver so the reserved local domain (default `test`) points at CoreDNS. With Colima you can see real service IPs (for example, 10.5.0.3) in the ANSWER section:

```bash
dig @dns.test registry.test
```

To change the domain, set `dns.domain` in `values.yaml`.

## Registries

Full registry support means the environment runs **local registry caches (mirrors)** of major registries—GCR, GHCR, Quay, Docker Hub, `registry.k8s.io`—so image pulls use local mirrors. A generic local registry is also available. Local registries run as containerized services. Common endpoints:

| Registry | Local endpoint |
|----------|-----------------|
| GCR, GHCR, Quay, Docker Hub, `registry.k8s.io` | http://*.test:5000 |
| Local generic | `http://registry.test:5000` |

Add mirrors in `windsor.yaml`:

```yaml
docker:
  registries:
    1234567890.dkr.ecr.us-east-1.amazonaws.com:
      remote: https://1234567890.dkr.ecr.us-east-1.amazonaws.com
```

`REGISTRY_URL` is set automatically. Cache lives in `.windsor/.docker-cache`.

## Build ID

```bash
windsor build-id                    # current build ID
windsor build-id --new              # generate new ID
```

Format: `YYMMDD.RANDOM.#`. Use with the local registry:

```bash
BUILD_ID=$(windsor build-id --new)
docker build -t ${REGISTRY_URL}/myapp:$BUILD_ID .
docker push ${REGISTRY_URL}/myapp:$BUILD_ID
```

## Local GitOps

[git-livereload](https://github.com/windsorcli/git-livereload) serves your repo at `http://git.test`. Flux reconciles from it; a webhook speeds up reconciliation. From another folder (Colima only):

```bash
git clone http://local@git.test/git/my-project
```

## Kubernetes cluster

A container-based cluster runs locally (for example, [Sidero Talos](https://github.com/siderolabs/talos)). Configure in `windsor.yaml`:

```yaml
cluster:
  enabled: true
  driver: talos
  controlplanes:
    count: 1
    cpu: 2
    memory: 2
  workers:
    count: 1
    cpu: 4
    memory: 4
    hostports:
    - 80:30080/tcp
    - 443:30443/tcp
    # ...
    volumes:
    - ${project_root}/.volumes:/var/mnt/local
```

Kubeconfig: `contexts/local/.kube/config`; `KUBECONFIG` is set for you. List nodes:

```bash
kubectl get nodes
```

The default stack includes Istio BookInfo. Visit `http://bookinfo.test:8080` and `https://bookinfo.test:8443` (or `:80`/`:443` if hostports are set).
