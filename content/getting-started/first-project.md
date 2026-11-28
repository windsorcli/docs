---
title: First project
description: Install the CLI, start a project, and run your first local stack.
---

For your first project, you will set up a local development environment running the core blueprint. This project is the basis used for the remaining examples in this guide. You will need a workstation with 6 free CPUs, 14 GB of RAM, and 60 GB of disk.

At the end of this tutorial, you will have a local cluster running on Docker Desktop. It will include basic services you need to run most application workloads including a complete observability stack.

## 1. Install the CLI

To begin, [install the CLI](https://www.windsorcli.dev/cli/installation) using instructions for your system. Make sure you have the most recent version of the CLI available.

```bash
windsor version
```

```text
Version: 0.10.1-dev
Commit SHA: a2b2eb8a1
Build Date: unknown
Go: go1.27.4
Platform: darwin/arm64
```

## 2. Install the prerequisites

Blueprints are written in part using HashiCorp Configuration Language (HCL). To deploy the core blueprint, Windsor calls `terraform` commands on your behalf. Windsor also has experimental support for OpenTofu, but it is not recommended for this tutorial.

The local development environment runs a cluster using Talos on Docker. Windows and macOS users should install Docker Desktop. Linux users may use the Docker client and engine running natively.

The Verify step uses `kubectl` to inspect the cluster.

Install the following:

- [Terraform](https://developer.hashicorp.com/terraform/install) 1.12.2 or later
- Docker 23.0.0 or later: Docker Desktop for [macOS](https://docs.docker.com/desktop/setup/install/mac-install/) or [Windows](https://docs.docker.com/desktop/setup/install/windows-install/), or [Docker Engine](https://docs.docker.com/engine/install/) on Linux
- [kubectl](https://kubernetes.io/docs/tasks/tools/)

If you also have the [Flux CLI](https://fluxcd.io/flux/installation/) and [kustomize](https://kubectl.docs.kubernetes.io/installation/kustomize/) installed, `windsor plan` uses them to show more detail about Kustomize changes. Neither is needed for this tutorial.

### Increase resourcing for Docker Desktop

1. Open Docker Desktop and select **Settings**.
2. Go to **VM resources** > **Advanced**.
3. Set **CPU limit** to 6, **Memory limit** to 14 GB, and **Disk usage limit** to at least 60 GB.
4. Select **Apply**.

## 3. Start a project

It is expected that you store your project files in a git repository. Create a new folder and initialize a git repository within it:

```bash
git init
```

To create the local context, run:

```bash
windsor init local
```

This command scaffolds your project and first context. It creates a basic `windsor.yaml` in your project root. It also creates a `contexts/local` directory populated with a `blueprint.yaml`, `values.yaml`, and `.gitignore`.

```text
.
├── .windsor/
│   ├── .gitignore
│   ├── cache/
│   └── context
├── contexts/
│   └── local/
│       ├── .gitignore
│       ├── blueprint.yaml
│       └── values.yaml
└── windsor.yaml
```

- `windsor.yaml` marks the project root.
- `contexts/local/blueprint.yaml` selects the blueprints the context deploys.
- `contexts/local/values.yaml` contains the context's settings.
- `contexts/local/.gitignore` keeps credentials out of git.
- `.windsor/` holds Windsor's cache and state. It isn't committed.

```yaml
# windsor.yaml
version: v1alpha2
```

```yaml
# contexts/local/blueprint.yaml
# This file selects and overrides components from underlying blueprint sources.
# To see the fully rendered blueprint, run: windsor show blueprint
kind: Blueprint
apiVersion: blueprints.windsorcli.dev/v1alpha1
metadata:
  name: local
  description: Blueprint for the local context
sources:
- name: core
  url: oci://ghcr.io/windsorcli/core:v0.9.0
  install: true
```

```yaml
# contexts/local/values.yaml
id: wstcvaqw
dev: true
terraform:
  backend:
    auto_prefix: true
dns:
  domain: test
```

Ensure that you are on the `local` context:

```bash
windsor get context
```

```text
local
```

To make sure that your tools are configured and configuration is valid, run:

```bash
windsor check
```

## 4. Start the environment

To start your development workstation, run:

```bash
windsor up
```

<details>
<summary>Output from a successful run</summary>

```text
● Applying terraform
  ✔ Applying workstation/docker  7s
  ✔ Applying compute/docker  6s
  ✔ Applying pki/ca  2s
  ✔ Applying cluster/talos  1m13s
  ✔ Applying gitops/flux  1m09s
● Applying kustomizations
  ✔ crds-core
  ✔ policy-install  1m10s
  ✔ policy-resources  5s
  ✔ csi-install  20s
  ✔ telemetry-install  1m07s
  ✔ telemetry-resources
  ✔ database-install  21s
  ✔ database-resources-catalog
  ✔ gateway-install  35s
  ✔ pki-install  49s
  ✔ pki-resources  2s
  ✔ gateway-resources-internal  7s
  ✔ observability-install  1m03s
  ✔ observability-resources  2s
  ✔ gitops-resources  7s
  ✔ dns-install  17s
  ✔ dns-resources-account  2s
  ✔ dns-resources-private  26s
Windsor environment set up successfully in 7m16s.

Notes
═══════════════════════════════════════════════
Grafana is ready at https://grafana.test:8443

Sign in with username 'admin' and password 'grafana'.

The gateway cert is self-signed. Trust the local CA, or click through
the browser warning on your first visit.

Next steps
═══════════════════════════════════════════════
Run 'windsor configure network' (asks for sudo) to use *.test in your browser.
```

</details>

This last step is optional and requires elevated privileges. This command will configure local DNS for the `*.test` top-level domain. The change is tightly scoped, but you should familiarize yourself with the [mechanism](../workstation/overview.md#your-machine). With this enabled, you are able to browse local services at subdomains including <https://grafana.test:8443> or <https://your-service.test:8443>.

```bash
windsor configure network
```

## 5. Verify

To verify your deployment, you can inspect the cluster and the generated configuration.

To list the cluster's nodes, run:

```bash
windsor exec -- kubectl get nodes
```

```text
NAME             STATUS   ROLES           AGE     VERSION
controlplane-1   Ready    control-plane   5m34s   v1.36.5
```

To list the Flux Kustomizations, run:

```bash
windsor exec -- kubectl get kustomizations -A
```

<details>
<summary>Output</summary>

```text
NAMESPACE       NAME                         AGE     READY   STATUS
system-gitops   crds-core                    4m35s   True    Applied revision: v0.9.0@sha256:9542bf4f7d9d1f68ce3e86755e9dba90b18855686e74bfee929b5a7a07824d8e
system-gitops   csi-install                  4m34s   True    Applied revision: v0.9.0@sha256:9542bf4f7d9d1f68ce3e86755e9dba90b18855686e74bfee929b5a7a07824d8e
system-gitops   database-install             4m34s   True    Applied revision: v0.9.0@sha256:9542bf4f7d9d1f68ce3e86755e9dba90b18855686e74bfee929b5a7a07824d8e
system-gitops   database-resources-catalog   4m34s   True    Applied revision: v0.9.0@sha256:9542bf4f7d9d1f68ce3e86755e9dba90b18855686e74bfee929b5a7a07824d8e
system-gitops   dns-install                  4m33s   True    Applied revision: v0.9.0@sha256:9542bf4f7d9d1f68ce3e86755e9dba90b18855686e74bfee929b5a7a07824d8e
system-gitops   dns-resources-account        4m32s   True    Applied revision: v0.9.0@sha256:9542bf4f7d9d1f68ce3e86755e9dba90b18855686e74bfee929b5a7a07824d8e
system-gitops   dns-resources-private        4m31s   True    Applied revision: v0.9.0@sha256:9542bf4f7d9d1f68ce3e86755e9dba90b18855686e74bfee929b5a7a07824d8e
system-gitops   gateway-install              4m31s   True    Applied revision: v0.9.0@sha256:9542bf4f7d9d1f68ce3e86755e9dba90b18855686e74bfee929b5a7a07824d8e
system-gitops   gateway-resources-internal   4m30s   True    Applied revision: v0.9.0@sha256:9542bf4f7d9d1f68ce3e86755e9dba90b18855686e74bfee929b5a7a07824d8e
system-gitops   gitops-resources             4m29s   True    Applied revision: v0.9.0@sha256:9542bf4f7d9d1f68ce3e86755e9dba90b18855686e74bfee929b5a7a07824d8e
system-gitops   observability-install        4m28s   True    Applied revision: v0.9.0@sha256:9542bf4f7d9d1f68ce3e86755e9dba90b18855686e74bfee929b5a7a07824d8e
system-gitops   observability-resources      4m27s   True    Applied revision: v0.9.0@sha256:9542bf4f7d9d1f68ce3e86755e9dba90b18855686e74bfee929b5a7a07824d8e
system-gitops   pki-install                  4m26s   True    Applied revision: v0.9.0@sha256:9542bf4f7d9d1f68ce3e86755e9dba90b18855686e74bfee929b5a7a07824d8e
system-gitops   pki-resources                4m26s   True    Applied revision: v0.9.0@sha256:9542bf4f7d9d1f68ce3e86755e9dba90b18855686e74bfee929b5a7a07824d8e
system-gitops   policy-install               4m26s   True    Applied revision: v0.9.0@sha256:9542bf4f7d9d1f68ce3e86755e9dba90b18855686e74bfee929b5a7a07824d8e
system-gitops   policy-resources             4m25s   True    Applied revision: v0.9.0@sha256:9542bf4f7d9d1f68ce3e86755e9dba90b18855686e74bfee929b5a7a07824d8e
system-gitops   telemetry-install            4m25s   True    Applied revision: v0.9.0@sha256:9542bf4f7d9d1f68ce3e86755e9dba90b18855686e74bfee929b5a7a07824d8e
system-gitops   telemetry-resources          4m24s   True    Applied revision: v0.9.0@sha256:9542bf4f7d9d1f68ce3e86755e9dba90b18855686e74bfee929b5a7a07824d8e
```

</details>

To print the composed blueprint, run:

```bash
windsor show blueprint
```

To print the context's values, run:

```bash
windsor show values
```

```yaml
id: wstcvaqw

platform: docker

dev: true

terraform:
  backend:
    auto_prefix: true

workstation:
  runtime: docker-desktop
  arch: arm64
  dns:
    address: 127.0.0.1

dns:
  domain: test

cluster:
  driver: talos
  controlplanes:
    nodes: {}
  workers:
    nodes: {}
```

You can also use Windsor's `explain` command to trace the facet sequence that contributed to a particular value:

```bash
windsor explain terraform.cluster.inputs.cluster_endpoint
```

```text
terraform.cluster.inputs.cluster_endpoint (deferred)
  /path/to/proj/.windsor/cache/oci/ghcr.io_windsorcli_core_v0.9.0/_template/facets/platform-docker.yaml:63
    cluster.endpoint (not set)
    cluster_endpoint_fallback.endpoint (deferred)
      /path/to/proj/.windsor/cache/oci/ghcr.io_windsorcli_core_v0.9.0/_template/facets/platform-docker.yaml:40
      cluster.controlplanes.nodes
```

## 6. Explore

Your local cluster comes bundled with the key services you need to operate your infrastructure. By default, when `dev: true`, a complete observability stack is installed. This is a good place to start to explore the system you've built.

### Open Grafana

If you have run `windsor configure network`, you should be able to navigate to services at `*.test` subdomains. Grafana is hosted at <https://grafana.test:8443>. Sign in with username `admin` and password `grafana`. When visiting, your browser will warn you of the unverified cert, which you should bypass.

### Tour the dashboards

When you enable features and services in a Windsor blueprint, appropriate Grafana dashboards are installed. You can navigate to the preset dashboards at [`https://grafana.test:8443/dashboards`](https://grafana.test:8443/dashboards).

Dashboards of particular interest include:

- [Kubernetes / Views / Global](https://grafana.test:8443/d/k8s_views_global/kubernetes-views-global) shows cluster-wide use. Its **Overview** row has the node count, running pods, and CPU and RAM use. The **Kubernetes** row graphs OOM events and container restarts by namespace.
- [Flux Cluster Stats](https://grafana.test:8443/d/flux-cluster/flux-cluster-stats) counts Flux reconcilers and how many are failing. The **Status** row lists the readiness of each Kustomization from the `windsor up` output.

### Turn on a demo app

A few demo apps are available to help test the Windsor platform and for illustrative purposes. You can enable Istio's BookInfo demo by adding the following to `contexts/local/values.yaml`:

```yaml
demo:
  enabled: true
  resources:
    bookinfo: true
```

You can see the changes that will be applied by running:

```bash
windsor plan
```

<details>
<summary>Output</summary>

```text
Windsor Plan Summary
══════════════════════════════════════════════════════

Terraform
  workstation/docker            (no changes)
  compute/docker                +0  ~1  -0
    ~ docker_container.containers["controlplane-1"]
  pki/ca                        (no changes)
  cluster/talos                 (no changes)
  gitops/flux                   (no changes)

Kustomize
  crds-core                     (no changes)
  csi-install                   (no changes)
  database-install              (no changes)
  database-resources-catalog    (no changes)
  demo-resources                (new)
    + Cluster/demo-database/demo-cluster
    + Deployment/demo-bookinfo/details-v1
    + Deployment/demo-bookinfo/productpage-v1
    + Deployment/demo-bookinfo/ratings-v1
    + Deployment/demo-bookinfo/reviews-v1
    + Deployment/demo-bookinfo/reviews-v2
    + Deployment/demo-bookinfo/reviews-v3
    + HTTPRoute/demo-bookinfo/productpage
    + Namespace/demo-bookinfo
    + Namespace/demo-database
    + Service/demo-bookinfo/details
    + Service/demo-bookinfo/productpage
    + Service/demo-bookinfo/ratings
    + Service/demo-bookinfo/reviews
    + ServiceAccount/demo-bookinfo/bookinfo-details
    + ServiceAccount/demo-bookinfo/bookinfo-productpage
    + ServiceAccount/demo-bookinfo/bookinfo-ratings
    + ServiceAccount/demo-bookinfo/bookinfo-reviews
  dns-install                   (no changes)
  dns-resources-account         (no changes)
  dns-resources-private         (no changes)
  gateway-install               (no changes)
  gateway-resources-internal    (no changes)
  gitops-resources              (no changes)
  observability-install         (no changes)
  observability-resources       (no changes)
  pki-install                   (no changes)
  pki-resources                 (no changes)
  policy-install                (no changes)
  policy-resources              (no changes)
  telemetry-install             (no changes)
  telemetry-resources           (no changes)

──────────────────────────────────────────────────────
  Run `windsor plan terraform <name>` or `windsor plan kustomize <name>` for full diffs.
```

</details>

Apply the changes by running:

```bash
windsor apply
```

After a moment to fully deploy, the app becomes available at <https://bookinfo.test:8443/productpage>.

To remove the demo app, set `demo.resources.bookinfo: false` in the `values.yaml` file and run:

```bash
windsor apply --prune
```

The demo also deploys a small Postgres database, because `demo.resources.database` defaults to `true`. This database can be observed at the [CloudNativePG dashboard](https://grafana.test:8443/d/cloudnative-pg/cloudnativepg), and should appear when running:

```bash
windsor exec -- kubectl get clusters.postgresql.cnpg.io -n demo-database
```

```text
NAME           AGE   INSTANCES   READY   STATUS                     PRIMARY
demo-cluster   71s   2           2       Cluster in healthy state   demo-cluster-1
```

## 7. Tear down

To tear down the local environment, you run:

```bash
windsor down
```

This is destructive and will completely remove all containers and credentials files in the local context.

## Next steps

- [Lifecycle](../provisioning/overview.md)
- [Contexts](../contexts/overview.md)
- [Workstation](../workstation/overview.md)
- [Components](../components/terraform.md)
