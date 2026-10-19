---
title: First project
description: Install the CLI, start a project, and run your first local stack.
---

This tutorial takes you from an empty directory to a single-node Kubernetes cluster running on your workstation. The cluster runs `core`, Windsor's default blueprint, so it comes up with Flux, a gateway, DNS, and Grafana already installed. Along the way you create a Windsor project and its first context, and you see each stage of the build as Windsor runs it.

Plan on giving the cluster about 6 CPU cores, 14 GB of RAM, and 60 GB of free storage beyond what your system already uses. Those numbers are a starting point, not an exact requirement: they cover `core` itself plus enough headroom for most development workloads.

## 1. Install the CLI

[Install Windsor](https://www.windsorcli.dev/cli/installation).

## 2. Terraform and a Docker runtime

Windsor builds the cluster's infrastructure with Terraform and runs the cluster's nodes as containers, so it depends on both tools. This tutorial uses Docker Desktop, the runtime that [`windsor init local`](https://www.windsorcli.dev/reference/cli/commands/init) picks by default on macOS and Windows. Install [Terraform](https://developer.hashicorp.com/terraform/install) and Docker Desktop for [macOS](https://docs.docker.com/desktop/setup/install/mac-install/) or [Windows](https://docs.docker.com/desktop/setup/install/windows-install/), then start Docker Desktop. If a tool is missing or too old, `windsor init` will instruct you to update.

The cluster runs inside Docker Desktop's VM, so the VM gets the starting allocation of 6 CPUs and 14 GB of memory. Set both under **Settings → Resources** before you run [`windsor up`](https://www.windsorcli.dev/reference/cli/commands/up). [Docker Desktop](../workstation/docker-desktop.md#resources) covers sizing in more detail.

On Linux, `windsor init local` uses Docker Engine on the host instead. The [workstation overview](../workstation/overview.md) compares the two with the Colima runtimes, which have their own setup.

## 3. Start a project

A Windsor *project* is a git repository with a `windsor.yaml` at its root. If it's not already, start by turning your project directory into a repository.

```bash
git init
```

Next, create the project and its first *context*. A context is a named environment, with its own blueprint, values, and credentials; this one is called `local`. Without `--vm-driver`, Windsor picks `docker-desktop` on macOS and Windows and `docker` on Linux.

```bash
windsor init local
```

`init` writes `windsor.yaml` at the repository root and a `contexts/local/` directory with a starter `blueprint.yaml` and `values.yaml`. [Contexts](../contexts/overview.md) describes the rest of the directory.

`windsor check` confirms that every tool the context depends on is installed at a supported version. On a cloud context it also confirms that your credentials resolve, which `local` doesn't use.

```bash
windsor check
```

`windsor get context` prints the active context, which is `local`. Every command that follows acts on it.

```bash
windsor get context
```

## 4. Start the environment

`windsor up` builds the stack in two stages. First it runs the Terraform phase, including the workstation network and node containers, a local certificate authority, the Talos cluster, and finally Flux. Next, Flux installs the rest of the blueprint into the cluster as "Kustomizations", Flux's unit of deployment. `--wait` keeps the command running until every Kustomization reports ready, which takes roughly 6 minutes on a fast Mac.

```bash
windsor up --wait
```

The output shows each stage as they are built, counting the duration each component takes to fully resolve.

<details>
<summary>Output from a successful run</summary>

```text
● Applying terraform
  ✔ Migrating terraform state  8s
  ✔ Applying workstation/docker  3s
  ✔ Applying compute/docker  2s
  ✔ Applying pki/ca
  ✔ Applying cluster/talos  1m04s
  ✔ Migrating terraform state  3s
  ✔ Applying gitops/flux  1m00s
● Applying kustomizations
  ✔ crds
  ✔ policy-install  50s
  ✔ policy-resources  5s
  ✔ csi-install  15s
  ✔ telemetry-install  30s
  ✔ telemetry-resources
  ✔ database-install  16s
  ✔ gateway-install  31s
  ✔ pki-install  31s
  ✔ pki-resources  5s
  ✔ gateway-resources-external  5s
  ✔ gateway-resources-internal  5s
  ✔ observability-install  46s
  ✔ gitops-resources  10s
  ✔ observability-resources  5s
  ✔ dns-install  40s
  ✔ dns-resources-account  5s
  ✔ dns-resources-public  25s
  ✔ dns-resources-private  25s
Windsor environment set up successfully in 6m10s.

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

When `up` finishes, it prints one follow-up command, [`windsor configure network`](https://www.windsorcli.dev/reference/cli/commands/configure-network). Your browser can't resolve `*.test` names until the host's DNS points at the cluster, requiring extra OS privileges. Run the command each time you stand up a fresh workstation. It prompts for sudo on macOS and Linux; on Windows, run it from an Administrator PowerShell.

```bash
windsor configure network
```

Colima works differently: the first `windsor up` stops early and asks for this command before it can finish, as it requires network configuration to reach nodes inside Colima's virtual machine. [Colima + Docker](../workstation/colima-docker.md) and [Colima + Incus](../workstation/colima-incus.md) walk through that flow.

## 5. Verify

Next, confirm the cluster and what windsor built. `kubectl get nodes` lists the node and its `Ready` status. `windsor show blueprint` prints the *composed blueprint*, the template merged with this context's values and overrides, which is the full list of what `up` just applied. `windsor show values` prints the context's values with every schema default filled in.

```bash
windsor exec -- kubectl get nodes
windsor show blueprint
windsor show values
```

When a value in that output surprises you, [`windsor explain <path>`](https://www.windsorcli.dev/reference/cli/commands/explain) traces it back to the file and expression that set it. This example traces the endpoint the Talos cluster module was given.

```bash
windsor explain terraform.cluster.inputs.cluster_endpoint
```

## 6. Explore

The cluster runs `core` in development mode. Before you tear it down, two parts of it are worth a look.

### Open Grafana

`core` installs Grafana with dashboards for the cluster already in place. Open `https://grafana.test:8443` and sign in as `admin` with the password `grafana`; `windsor up` printed the same address and login when it finished. The gateway serves a certificate from the cluster's private CA, so your browser warns until you trust that CA.

Port 8443 is specific to Docker Desktop. The other runtimes serve on the default HTTPS port, so on those, leave off `:8443`.

### Tour the dashboards

`core` files its dashboards into folders under **Dashboards** in Grafana's menu: System for the cluster and its node, GitOps for Flux, and Networking for the gateway. Five of them give a quick picture of the cluster you just built. On a runtime other than Docker Desktop, drop `:8443` from these links.

1. [Kubernetes / Views / Global](https://grafana.test:8443/d/k8s_views_global/kubernetes-views-global) shows CPU, memory, and network use across the whole cluster. At this point almost all of it is `core` itself.
2. [Kubernetes / Views / Pods](https://grafana.test:8443/d/k8s_views_pods/kubernetes-views-pods) narrows the view to one pod. Set **namespace** to `system-observability` and **pod** to the Grafana pod to see what the dashboard in front of you costs to run.
3. [Node Exporter Full](https://grafana.test:8443/d/rYdddlPWk/node-exporter-full) reads the node itself: CPU per core, memory, disk, and network for the single Talos node running in a Docker container.
4. [Flux Cluster Stats](https://grafana.test:8443/d/flux-cluster/flux-cluster-stats) lists every Flux resource with its reconciliation status. The Kustomization names match the second stage of `windsor up`'s output, such as `gateway-install` and `observability-resources`.
5. [Envoy Global](https://grafana.test:8443/d/heHhNSFf6Na8vIZWRs8H/envoy-global) shows the traffic passing through the gateway, including the requests your browser just made to Grafana.

### Turn on a demo app

`core` ships sample apps that are off by default, and you turn one on the same way you change anything else in the blueprint: by editing the context's values. Add these lines to `contexts/local/values.yaml` to turn on BookInfo, a small multi-service web app.

```yaml
demo:
  enabled: true
  resources:
    bookinfo: true
```

Preview the change before you make it. [`windsor plan`](https://www.windsorcli.dev/reference/cli/commands/plan) composes the blueprint with the new values and compares the result with what is already applied, without changing anything.

```bash
windsor plan
```

The summary marks the `demo` Kustomizations as `(new)`, because they have never been applied. The Terraform components show no changes: the demo facet adds only Flux systems, so BookInfo runs entirely inside the cluster.

Now apply the change. `windsor apply` installs what the plan showed and nothing else.

```bash
windsor apply
```

When it finishes, open `https://bookinfo.test:8443/productpage`.

To remove the app, delete the `demo` lines and run `windsor apply --prune`. `--prune` also removes Kustomizations that the blueprint no longer declares, which is what takes BookInfo out of the cluster.

Grafana and BookInfo both come from `core`. To run your own Terraform modules and Kustomize manifests alongside it, see [Terraform](../components/terraform.md) and [Kustomize](../components/kustomize.md).

## 7. Tear down

On a workstation, `windsor down` is all the teardown you need. It removes the local environment directly, including the containers, volumes, and network that `up` created on Docker.

```bash
windsor down
```

`windsor down` skips the orderly Kubernetes teardown that [`windsor destroy`](https://www.windsorcli.dev/reference/cli/commands/destroy) performs, because the containers holding the cluster go away with it. On a cloud or metal context, where the infrastructure outlives your machine, run `windsor destroy` first. [Destroy](../provisioning/destroy.md) covers when each applies.

## Next steps

- [Lifecycle](../provisioning/overview.md): the commands behind what you just ran, and how it differs for a cloud or metal context
- [Contexts](../contexts/overview.md): multiple environments and switching
- [Workstation](../workstation/overview.md): the local runtimes and what `windsor up` builds
- [Components](../components/terraform.md): adding your own Terraform and Kustomize to a consumed blueprint
