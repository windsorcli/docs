---
title: First project
description: Install the CLI, start a project, and run your first local stack.
---

<!-- ai: rough draft -->

This tutorial takes you from an empty directory to a single-node Kubernetes cluster running on your workstation. The cluster runs `core`, Windsor's default blueprint, so it comes up with Flux, a gateway, DNS, and Grafana already installed. Along the way you create a Windsor project and its first context, and you watch each stage of the build as Windsor runs it.

The cluster's node gets 4 CPUs and 12 GB of memory. Give Docker Desktop about 6 CPUs, 14 GB of memory, and 60 GB of free disk, so the node fits with room for Docker Desktop itself and your own workloads.

## 1. Install the CLI

[Install Windsor](https://www.windsorcli.dev/cli/installation), then check that it runs:

```bash
windsor version
```

## 2. Terraform and a Docker runtime

Windsor builds the cluster's infrastructure with Terraform and runs the cluster's node as a container, so it uses both tools. This tutorial uses Docker Desktop, the runtime [`windsor init local`](https://www.windsorcli.dev/reference/cli/commands/init) picks on macOS and Windows. Install [Terraform](https://developer.hashicorp.com/terraform/install) 1.12.2 or later, Docker Desktop for [macOS](https://docs.docker.com/desktop/setup/install/mac-install/) or [Windows](https://docs.docker.com/desktop/setup/install/windows-install/), and [kubectl](https://kubernetes.io/docs/tasks/tools/), then start Docker Desktop.

Set the VM's CPUs and memory under **Settings → Resources** before you run [`windsor up`](https://www.windsorcli.dev/reference/cli/commands/up). Docker Desktop must give the VM at least 4 CPUs, or the node container fails to start. [Docker Desktop](../workstation/docker-desktop.md#resources) covers sizing in more detail.

On Linux, `windsor init local` uses Docker Engine on the host instead. The [workstation overview](../workstation/overview.md) compares the two with the Colima runtimes, which have their own setup.

## 3. Start a project

A Windsor *project* is a git repository with a `windsor.yaml` at its root. `windsor init` refuses to run outside a repository, so start there:

```bash
git init
```

Next, create the project and its first *context*. A context is a named environment, with its own blueprint, values, and credentials. This one is called `local`. Without `--vm-driver`, Windsor picks `docker-desktop` on macOS and Windows and `docker` on Linux.

```bash
windsor init local
```

```text
Initialization successful
```

`init` writes `windsor.yaml` at the repository root and a `contexts/local/` directory with a `blueprint.yaml` and a `values.yaml`. The blueprint lists `core` as its only source:

```yaml
# contexts/local/blueprint.yaml
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

[Contexts](../contexts/overview.md) describes the rest of the directory.

`init` does not check your tools, so it works on a machine that has neither Docker nor Terraform yet. [`windsor check`](https://www.windsorcli.dev/reference/cli/commands/check) does. It prints nothing when every tool the context uses is installed at a supported version, and names the missing or outdated tool otherwise:

```bash
windsor check
```

`windsor get context` prints the active context, `local`. Every command that follows acts on it.

```bash
windsor get context
```

## 4. Start the environment

`windsor up` builds the stack in two stages. First it applies the Terraform components: the workstation network and DNS, the node container, a local certificate authority, the Talos cluster, and Flux. Then Flux installs the rest of the blueprint into the cluster as *Kustomizations*, Flux's unit of deployment. `up` keeps running until every Kustomization reports ready. The first run took 8 minutes on an Apple Silicon Mac.

```bash
windsor up
```

The output lists each step as it finishes, with the time it took.

<details>
<summary>Output from a successful run</summary>

<!-- ai: real TTY output of windsor up; the step names and times below are from a non-TTY run -->

```text
● Applying terraform
  ✔ Applying workstation/docker  4s
  ✔ Applying compute/docker  3s
  ✔ Applying pki/ca  1s
  ✔ Applying cluster/talos  1m14s
  ✔ Applying gitops/flux  1m11s
● Applying kustomizations
  ✔ crds-core
  ✔ policy-install  50s
  ✔ policy-resources  5s
  ✔ csi-install  15s
  ✔ telemetry-install  1m11s
  ✔ database-install  16s
  ✔ telemetry-resources  17s
  ✔ gateway-install  18s
  ✔ database-resources-catalog  10s
  ✔ pki-install  53s
  ✔ pki-resources  3s
  ✔ observability-install  58s
  ✔ gateway-resources-internal  7s
  ✔ observability-resources  4s
  ✔ gitops-resources  8s
  ✔ dns-install  17s
  ✔ dns-resources-account  2s
  ✔ dns-resources-private  1m31s
Windsor environment set up successfully in 8m01s.

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

When `up` finishes, it prints one follow-up command, [`windsor configure network`](https://www.windsorcli.dev/reference/cli/commands/configure-network). Your browser can't resolve `*.test` names until the host's DNS sends them to the cluster, and changing the host's DNS takes elevated privileges. The command prompts for sudo on macOS and Linux. On Windows, run it from an Administrator PowerShell. Run it each time you stand up a fresh workstation.

```bash
windsor configure network
```

On Colima, the first `windsor up` stops early under an **Action required** heading and asks for this command, because the host needs a route to reach the node inside Colima's VM. Run it, then run `windsor up` again. [Colima + Docker](../workstation/colima-docker.md) and [Colima + Incus](../workstation/colima-incus.md) walk through that flow.

## 5. Verify

Confirm that the cluster is up. `kubectl get nodes` lists the node and its status. `windsor exec` runs it with the context's `KUBECONFIG`.

```bash
windsor exec -- kubectl get nodes
```

```text
NAME             STATUS   ROLES           AGE     VERSION
controlplane-1   Ready    control-plane   6m51s   v1.36.5
```

`windsor show blueprint` prints the *composed blueprint*: `core` merged with this context's values and overrides, which is the full list of what `up` applied. `windsor show values` prints the context's values with every schema default filled in.

```bash
windsor show blueprint
windsor show values
```

When a value in that output surprises you, [`windsor explain <path>`](https://www.windsorcli.dev/reference/cli/commands/explain) traces it to the file and line that set it. This example traces the endpoint the Talos cluster module receives.

```bash
windsor explain terraform.cluster.inputs.cluster_endpoint
```

```text
terraform.cluster.inputs.cluster_endpoint (deferred)
  /path/to/project/.windsor/cache/oci/ghcr.io_windsorcli_core_v0.9.0/_template/facets/platform-docker.yaml:63
    cluster.endpoint (not set)
    cluster_endpoint_fallback.endpoint (deferred)
      /path/to/project/.windsor/cache/oci/ghcr.io_windsorcli_core_v0.9.0/_template/facets/platform-docker.yaml:40
      cluster.controlplanes.nodes
```

The input comes from line 63 of `core`'s `platform-docker` facet. `cluster.endpoint` is not set in your values, so the facet falls back to an address built from the control plane nodes. `(deferred)` marks a value that Windsor resolves at apply time, from another component's output.

## 6. Explore

The cluster runs `core` in development mode. Before you tear it down, two parts of it are worth a look.

### Open Grafana

`core` installs Grafana with dashboards for the cluster already in place. Open `https://grafana.test:8443` and sign in as `admin` with the password `grafana`; `windsor up` printed the same address and login when it finished. The gateway serves a certificate from the cluster's private CA, so your browser warns until you trust that CA.

Port 8443 is specific to Docker Desktop, which publishes the gateway on that host port. The other runtimes give the gateway its own address and serve on the default HTTPS port, so on those, leave off `:8443`.

### Tour the dashboards

`core` files its dashboards into folders under **Dashboards** in Grafana's menu, such as System for the cluster and its node, GitOps for Flux, and Networking for the gateway. Five of them give a quick picture of the cluster you just built.

1. [Kubernetes / Views / Global](https://grafana.test:8443/d/k8s_views_global/kubernetes-views-global) shows CPU, memory, and network use across the whole cluster. At this point almost all of it is `core` itself.
2. [Kubernetes / Views / Pods](https://grafana.test:8443/d/k8s_views_pods/kubernetes-views-pods) narrows the view to one pod. Set **namespace** to `system-observability` and **pod** to the Grafana pod to see what the dashboard in front of you costs to run.
3. [Node Exporter Full](https://grafana.test:8443/d/rYdddlPWk/node-exporter-full) reads the node itself: CPU per core, memory, disk, and network for the single Talos node running in a Docker container.
4. [Flux Cluster Stats](https://grafana.test:8443/d/flux-cluster/flux-cluster-stats) lists every Flux resource with its reconciliation status. The Kustomization names match the second stage of `windsor up`'s output, such as `gateway-install` and `observability-resources`.
5. [Envoy Global](https://grafana.test:8443/d/heHhNSFf6Na8vIZWRs8H/envoy-global) shows the traffic passing through the gateway, including the requests your browser just made to Grafana.

On a runtime other than Docker Desktop, drop `:8443` from links 1 to 4. Link 5 has no equivalent there, because the gateway on those runtimes is Cilium instead of Envoy.

### Turn on a demo app

`core` ships sample apps that are off by default, and you turn one on the same way you change anything else in the blueprint: by editing the context's values. Add these lines to `contexts/local/values.yaml` to turn on BookInfo, a small multi-service web app. `core` adds a demo Postgres cluster with it, because `demo.resources.database` is on by default.

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

The summary marks one new Kustomization, `demo-resources`, as `(new)`. It lists the Deployments, Services, and route it adds in the `demo-bookinfo` namespace, and the Postgres `Cluster` in `demo-database`. The demo adds no Terraform. The `compute/docker` change the summary also shows is not the demo's: `plan` reports it on every run.

Now apply the change. [`windsor apply`](https://www.windsorcli.dev/reference/cli/commands/apply) installs what the plan showed.

```bash
windsor apply
```

When it finishes, open `https://bookinfo.test:8443/productpage`.

To remove the app, delete the `demo` lines. `windsor plan` now lists `demo-resources` as no longer declared. `windsor apply --prune` removes it from the cluster; without `--prune`, `apply` leaves it running and lists it.

```bash
windsor apply --prune
```

Grafana and BookInfo both come from `core`. To run your own Terraform modules and Kustomize manifests alongside it, see [Terraform](../components/terraform.md) and [Kustomize](../components/kustomize.md).

## 7. Tear down

On a workstation, [`windsor down`](https://www.windsorcli.dev/reference/cli/commands/down) is all the teardown you need. It removes the node and registry-mirror containers, their volumes, and the `windsor-local` network that `up` created, and deletes the context's kubeconfig and Talos config.

```bash
windsor down
```

`windsor down` skips the orderly Kubernetes teardown that [`windsor destroy`](https://www.windsorcli.dev/reference/cli/commands/destroy) performs, because the containers holding the cluster go away with it. On a cloud or metal context, where the infrastructure outlives your machine, run `windsor destroy` instead; `down` does nothing there. [Destroy](../provisioning/destroy.md) covers when each applies.

## Next steps

- [Lifecycle](../provisioning/overview.md): the commands behind what you just ran, and how they differ for a cloud or metal context
- [Contexts](../contexts/overview.md): multiple environments and switching
- [Workstation](../workstation/overview.md): the local runtimes and what `windsor up` builds
- [Components](../components/terraform.md): adding your own Terraform and Kustomize to a consumed blueprint
