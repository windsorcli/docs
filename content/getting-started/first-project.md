---
title: First project
description: Install the CLI, start a project, and run your first local stack.
---

This guide walks through installing Windsor, starting a project, and launching a local Kubernetes cluster with a single worker and controlplane.

Recommended: 8 CPU cores, 8GB RAM, 60GB free storage.

## 1. Install the CLI

[Install Windsor](/cli/installation).

## 2. Terraform and a Docker runtime

You need Terraform and a Docker runtime (Colima, Docker Desktop, or another [supported option](/workstation/colima-docker)). Install them however you prefer. When you run `windsor init`, it will tell you if a required tool is missing or needs upgrading.

## 3. Start a project

Ensure you have a git repository in the project root:

```bash
git init
```

Initialize Windsor for local. Without `--vm-driver`, Windsor picks `docker-desktop` on macOS/Windows and `docker` on Linux:

```bash
windsor init local
# Or, for a specific runtime:
# windsor init local --vm-driver colima        # Apple silicon, Linux
# windsor init local --vm-driver colima-incus  # Apple silicon (nested virt), Linux
# windsor init local --vm-driver docker-desktop
# windsor init local --vm-driver docker
```

| Driver | Platform | Default on |
|--------|----------|------------|
| `docker-desktop` | macOS, Windows, Linux | macOS, Windows |
| `docker` | Linux | Linux |
| `colima` | Apple silicon, Linux | — |
| `colima-incus` | Apple silicon (nested virt), Linux | — |

Validate the toolchain:

```bash
windsor check
```

Confirm the default context:

```bash
windsor get context
```

## 4. Start the environment

Start the workstation VM, run Terraform for workstation infrastructure, and install the Flux blueprint:

```bash
windsor up --wait
```

`--wait` blocks until every Kustomization reports ready. Expect roughly 5 minutes on a fast Mac.

`up` does not prompt for elevation, so it defers host networking and DNS and prints a `windsor configure network` command (prompts for sudo on macOS/Linux; run from an Administrator PowerShell on Windows). On **Colima**, `up` halts until the host route is installed, so the first-run sequence is `up` → `configure network` → `up` again:

```bash
windsor configure network
windsor up                      # re-run, if up halted asking for it
```

On **Docker Desktop** `up` completes without halting; run `configure network` once afterward to activate `*.test` resolution. Either way, writing the DNS resolver entry needs elevation.

While it runs, watch progress in another shell. These `kubectl` commands use your context's `KUBECONFIG`, so either prefix each with `windsor exec --` or set up the [shell hook](/contexts/environment-injection) once so it's exported automatically:

```bash
kubectl get kustomizations -A --watch
kubectl get helmreleases -A
kubectl get pods -A
```

## 5. Verify

```bash
kubectl get nodes               # nodes Ready
windsor show blueprint          # fully composed blueprint
windsor show values             # effective context values
```

`windsor explain <path>` traces a value back to its source in the composition:

```bash
windsor explain terraform.cluster.inputs.cluster_endpoint
```

## 6. Tear down

```bash
windsor destroy --confirm=local
windsor down
```

`destroy` removes the live infrastructure (Terraform state and Flux Kustomizations). `down` stops the VM and clears local context artifacts. `--confirm=local` is the non-interactive equivalent of typing `local` at the destroy prompt.

## Next steps

- [Contexts](/contexts/overview) — Multiple environments and switching
- [Workstation](/workstation/colima-docker) — Local virtualization (Colima, Docker Desktop)
- [Blueprints](/blueprints/overview) and [Components](/blueprints/terraform) — Terraform and Kustomize
