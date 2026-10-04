---
title: First project
description: Install the CLI, start a project, and run your first local stack.
---

Install Windsor, start a project, and launch a local single-node Kubernetes cluster.

The cluster needs about 6 CPU cores and 14 GB of RAM, plus 60 GB of free storage, on top of what your system already uses.

## 1. Install the CLI

[Install Windsor](https://www.windsorcli.dev/cli/installation).

## 2. Terraform and a Docker runtime

This guide uses Docker Desktop, which [`windsor init local`](https://www.windsorcli.dev/reference/cli/commands/init) picks by default on macOS and Windows. Install Terraform and [Docker Desktop](https://docs.docker.com/desktop/), and start Docker Desktop. When you run `windsor init`, it tells you if a required tool is missing or needs upgrading.

Docker Desktop's VM needs at least 6 CPUs and 14 GB of memory for the cluster. Set them under **Settings → Resources** in Docker Desktop before you run [`windsor up`](https://www.windsorcli.dev/reference/cli/commands/up). See [Docker Desktop](../workstation/docker-desktop.md#resources) for more information on resourcing.

On Linux, `windsor init local` uses Docker Engine on the host instead. The [workstation overview](../workstation/overview.md) compares these with the Colima runtimes, which have their own setup.

## 3. Start a project

Ensure you have a git repository in the project root:

```bash
git init
```

Initialize Windsor for local. Without `--vm-driver`, Windsor picks `docker-desktop` on macOS and Windows and `docker` on Linux:

```bash
windsor init local
```

Validate the toolchain:

```bash
windsor check
```

Confirm the default context:

```bash
windsor get context
```

## 4. Start the environment

Start the cluster, run Terraform for the workstation infrastructure, and install the Flux blueprint:

```bash
windsor up --wait
```

`--wait` blocks until every Kustomization reports ready. Expect roughly 5 minutes on a fast Mac.

While it runs, watch progress in another shell. These `kubectl` commands use your context's `KUBECONFIG`, so either prefix each with [`windsor exec --`](https://www.windsorcli.dev/reference/cli/commands/exec) or set up the [shell hook](../contexts/environment-injection.md) once so it's exported automatically:

```bash
kubectl get kustomizations -A --watch
kubectl get helmreleases -A
kubectl get pods -A
```

When `up` finishes, it prints a [`windsor configure network`](https://www.windsorcli.dev/reference/cli/commands/configure-network) command. `up` does not ask for elevation, so this step is separate. Run it once so `*.test` names resolve in your browser. It prompts for sudo on macOS and Linux, and on Windows you run it from an Administrator PowerShell:

```bash
windsor configure network
```

If you use Colima, the first `windsor up` stops early and asks for this command before it can finish. See [Colima + Docker](../workstation/colima-docker.md) or [Colima + Incus](../workstation/colima-incus.md) for that flow.

## 5. Verify

```bash
kubectl get nodes               # nodes Ready
windsor show blueprint          # fully composed blueprint
windsor show values             # effective context values
```

[`windsor explain <path>`](https://www.windsorcli.dev/reference/cli/commands/explain) traces a value back to its source in the composition:

```bash
windsor explain terraform.cluster.inputs.cluster_endpoint
```

## 6. Explore

The cluster runs `core`, Windsor's default blueprint, in development mode. Two things worth a look before you tear it down.

### Open Grafana

Grafana comes fully configured with dashboards for your environment. Open `https://grafana.test:8443` and sign in as `admin` with the password `grafana`. The gateway serves a certificate from the cluster's private CA, so your browser warns until you trust it. Only Docker Desktop uses port 8443. Other runtimes use the default HTTPS port, so leave off `:8443`. When `windsor up` finishes, it also prints the Grafana address and login. Two good places to start are [Kubernetes / Views / Global](https://grafana.test:8443/d/k8s_views_global/kubernetes-views-global), for cluster-wide resource use, and [Flux Cluster Stats](https://grafana.test:8443/d/flux-cluster/flux-cluster-stats), the cluster reconciliation status.

### Turn on a demo app

`core` includes sample apps that are off by default. Add two values to `contexts/local/values.yaml` to turn on BookInfo, a small multi-service web app:

```yaml
demo:
  enabled: true
  resources:
    bookinfo: true
```

Run `windsor apply`. It composes the blueprint with your new values and installs what changed. When it finishes, open `https://bookinfo.test:8443/productpage`. To remove the app later, delete the `demo` values and run `windsor apply --prune`, which also removes Kustomizations that the blueprint no longer declares.

Grafana and BookInfo both come from `core`. To run your own Terraform modules and Kustomize manifests alongside `core`, see [Terraform](../components/terraform.md) and [Kustomize](../components/kustomize.md).

## 7. Tear down

```bash
windsor destroy --confirm=local
windsor down
```

`destroy` removes the live infrastructure (Terraform state and Flux Kustomizations). `down` stops the VM and clears local context artifacts. `--confirm=local` is the non-interactive equivalent of typing `local` at the destroy prompt.

## Next steps

- [Lifecycle](../provisioning/workflow.md): the commands behind what you just ran, and how it differs for a cloud or metal context
- [Contexts](../contexts/overview.md): multiple environments and switching
- [Workstation](../workstation/overview.md): the local runtimes and what `windsor up` builds
- [Components](../components/terraform.md): adding your own Terraform and Kustomize to a consumed blueprint
