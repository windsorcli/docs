---
title: Docker Desktop
description: Run a workstation context on Docker Desktop, with the supported systems, recommended resources, and what gets built.
---

Docker Desktop is the quickest way to get a workstation context running, and the default on macOS and Windows. The cluster nodes run as containers inside Docker Desktop's VM, and your machine reaches them through ports published on localhost.

## Supported systems

macOS, Windows, and Linux. On Linux with Docker Engine instead of Docker Desktop, use `--vm-driver docker`.

## Install

Install [Docker Desktop](https://docs.docker.com/desktop/) and start it before you run `windsor up`. Docker Desktop provides the Docker daemon. Windsor doesn't manage it.

## Resources

Docker Desktop's VM limits are set in Docker Desktop, not in Windsor. Open **Settings → Resources** and set them there. See [Docker's settings reference](https://docs.docker.com/desktop/settings-and-maintenance/settings/).

The default cluster is one node, limited to 4 CPUs and 12 GB of memory. That node runs the workloads as well as the control plane, which is why it gets the larger memory figure. It used around 9 GB at rest on a default install, and the DNS, registry mirrors, and git mirror add a few hundred MB more. Docker Desktop's VM has to hold all of it, so give it at least:

- **CPUs:** 6
- **Memory:** 14 GB
- **Disk:** about 60 GB free, for images and the registry cache

Each worker you add brings its own limit of 4 CPUs and 8 GB, so raise these to match. A dedicated control plane, with workers to carry the workloads, needs 8 GB of memory instead of 12. To change a node's limits, set `cluster.controlplanes.cpu` and `cluster.controlplanes.memory` in `contexts/local/values.yaml`.

## Start it

```bash
windsor init local --vm-driver docker-desktop
windsor up --wait
windsor configure network        # once; prompts for sudo (Administrator PowerShell on Windows)
```

`up` finishes without halting. `configure network` only writes the DNS rule, and it needs elevation.

## What gets built

```mermaid
flowchart TB
  subgraph Host["Your machine"]
    CLI["windsor · kubectl · docker"]
    Resolver["DNS rule<br/>*.test → 127.0.0.1"]
  end
  subgraph VM["Docker Desktop VM · windsor-local"]
    Support["dns.test · registry mirrors · git.test"]
    Node["controlplane-1<br/>Talos container"]
  end
  CLI -.->|"localhost:6443"| Node
  CLI -.->|"localhost:8080, :8443"| Node
  Resolver -.-> Support
```

- **Nodes are containers.** `controlplane-1` runs Talos as a privileged container on the `windsor-local` bridge, next to the support containers described in the [overview](overview.md#what-gets-built).
- **Localhost access.** The container publishes the Kubernetes API on `6443`, the Talos API on `50000`, and the cluster's HTTP and HTTPS ports on `8080` and `8443`. That's why the demo is at `http://bookinfo.test:8080`.
- **DNS answers `127.0.0.1`.** Every `*.test` name resolves to localhost, and the published ports do the routing. There's no route to the cluster network, so the host can't reach service IPs or a layer 2 load balancer.
- **Flannel, not Cilium.** Cilium has no working transport over Docker Desktop's loopback, so Windsor sets the CNI to Flannel for this runtime.

Filesystem volumes work as usual: `${project_root}/.volumes` is bind-mounted into the node so persistent volumes show up as folders in your project. Block devices aren't available. For them, use [Colima + Incus](colima-incus.md).
