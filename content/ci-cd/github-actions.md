---
title: GitHub Actions
description: Installing the Windsor CLI in a workflow, authenticating to a cloud platform, and wrapping windsor commands as steps.
---

The [Windsor GitHub Action](https://github.com/windsorcli/action) installs and configures the Windsor CLI for use in GitHub Actions workflows, and provides a sub-action per `windsor` command so a workflow doesn't need to hand-write `run: windsor <command>` steps.

## Install the CLI

```yaml
- uses: windsorcli/action@v1
  with:
    ref: v1.0.0        # a release tag, a git ref to build from source, or "nightly"
    context: staging
    workdir: terraform/cluster/eks
```

`ref` defaults to the action's own pinned CLI release. `context` sets the context every later step runs against; `install-only: true` skips context init and environment injection if you only need the binary on `PATH`. Every sub-action below expects `windsor` already installed this way — none of them install the CLI themselves, and each fails fast with an actionable message if it can't find one on `PATH`.

Every sub-action, including this one, emits a `context` output (`windsor get context` after the command runs), so a later step can label an artifact or log line without an extra call.

## Cloud authentication

`windsorcli/action/cloud-auth` authenticates the runner to the context's cloud platform, so a job never holds a static, long-lived credential. It reads the platform from `windsor get contexts` for the active context, or skip that lookup by passing `platform` directly:

```yaml
- uses: windsorcli/action/cloud-auth@v1
  with:
    aws-role-arn: ${{ vars.AWS_ROLE_ARN }}
    aws-region: ${{ vars.AWS_REGION }}
```

Only the inputs for your platform are required — leave the rest unset. Each platform delegates to the upstream action that already handles it well, rather than reimplementing OIDC exchange itself:

| Platform | Delegates to | Required inputs |
|---|---|---|
| `aws` | [`aws-actions/configure-aws-credentials`](https://github.com/aws-actions/configure-aws-credentials) | `aws-role-arn`, `aws-region` |
| `azure` | [`azure/login`](https://github.com/Azure/login) + [`azure/use-kubelogin`](https://github.com/Azure/use-kubelogin) | `azure-client-id`, `azure-tenant-id`, `azure-subscription-id` |
| `gcp` | [`google-github-actions/auth`](https://github.com/google-github-actions/auth) + `gke-gcloud-auth-plugin` | `gcp-workload-identity-provider`, `gcp-service-account` |
| `hetzner` | a plain `HCLOUD_TOKEN` env var | `hetzner-token` |

A platform that needs no cloud credentials (`none`, `docker`, `incus`, `metal`, `hyperv`, `vsphere`) is a no-op. An unrecognized platform, or a missing required input for the detected one, fails immediately rather than surfacing as an opaque auth error later.

### Setting up the trust relationship

This action only removes the per-platform `if:` branching — it still expects the OIDC trust relationship configured on the cloud side, the same as if you called the upstream action directly. Set that up once, following that platform's own docs, before the inputs above have anything to authenticate against:

- AWS: an IAM OIDC identity provider trusting `token.actions.githubusercontent.com`, and a role with a trust policy scoped to your repo (and branch, if you want that granularity) — see [`aws-actions/configure-aws-credentials`](https://github.com/aws-actions/configure-aws-credentials#sample-iam-role-cloudformation-template).
- Azure: a federated credential on an app registration, scoped to the repo and ref — see [`azure/login`](https://github.com/Azure/login#login-with-openid-connect-oidc-recommended).
- GCP: a Workload Identity Pool and provider trusting GitHub's OIDC issuer, attached to a service account — see [`google-github-actions/auth`](https://github.com/google-github-actions/auth#setting-up-workload-identity-federation).
- Hetzner: no OIDC — `hetzner-token` is a plain API token from a repo secret. There's no short-lived-credential option here.

Job permissions need `id-token: write` for the OIDC-based platforms (AWS, Azure, GCP) — without it, the upstream action has nothing to exchange.

Short-lived credentials expire. Call `cloud-auth` again later in a long job to refresh them. One gap this doesn't cover: `kubelogin`'s `workloadidentity` mode reads Azure's federated token from a file once and never refreshes it, while GitHub's own OIDC token lasts about 5 minutes — a long `up`, `bootstrap`, or `apply` against AKS can fail partway through once it expires. The [action's README](https://github.com/windsorcli/action#refreshing-kubelogins-azure-token-on-a-long-job) has a wrapper-script recipe for it; it's a real gap, not something `cloud-auth` papers over.

## The lifecycle sub-actions

Each wraps one `windsor` command, taking the same `workdir` input as the root action:

| Sub-action | Wraps | Notable inputs |
|---|---|---|
| [`windsorcli/action/check`](https://github.com/windsorcli/action/tree/main/check) | `windsor check` | — |
| [`windsorcli/action/up`](https://github.com/windsorcli/action/tree/main/up) | `windsor up` | `wait`, `vm-driver`, `platform`, `blueprint`, `set` |
| [`windsorcli/action/bootstrap`](https://github.com/windsorcli/action/tree/main/bootstrap) | `windsor bootstrap` | `yes` (**required**), `context`, `platform`, `blueprint`, `set` |
| [`windsorcli/action/apply`](https://github.com/windsorcli/action/tree/main/apply) | `windsor apply` | `wait`, `prune`, `terraform-component`, `kustomize-name` |
| [`windsorcli/action/destroy`](https://github.com/windsorcli/action/tree/main/destroy) | `windsor destroy` | `confirm` (**required**), `component`, `layer`, `continue` |

`bootstrap`'s `yes` and `destroy`'s `confirm` are required for the same reason: both commands prompt for confirmation interactively, and CI has no TTY to answer. `confirm` takes the same context or component name the interactive prompt would ask for. `terraform-component` and `kustomize-name` on `apply` are mutually exclusive, matching `windsor apply terraform <component>` and `windsor apply kustomize <name>`; neither accepts `wait` or `prune`, since `apply terraform` alone has no such flags.

```yaml
- uses: windsorcli/action/bootstrap@v1
  with:
    context: staging
    platform: aws
    blueprint: oci://ghcr.io/myorg/blueprint:v1.0.0
    yes: true

- uses: windsorcli/action/destroy@v1
  with:
    confirm: staging
```

## Posting plan output to a pull request

`windsorcli/action/plan-comment` runs `windsor plan --summary --no-color` and posts the result as a sticky PR comment — a later push updates that same comment instead of piling up new ones, matched by a hidden marker keyed on the context name so a matrix of contexts each get their own. It defaults to the triggering PR, so it's meant for a `pull_request`-triggered workflow; pass `pr-number` to target another one. A failed `windsor plan` still gets posted with its real error, then the step fails so the job goes red too.

```yaml
permissions:
  pull-requests: write

steps:
  - uses: windsorcli/action/plan-comment@v1
```

Requires `permissions: pull-requests: write` on the calling job.

## Example workflow

A manually triggered workflow that bootstraps or destroys a context, chaining the root action, `cloud-auth`, and `bootstrap`/`destroy`:

```yaml
on:
  workflow_dispatch:
    inputs:
      action:
        type: choice
        options: [bootstrap, destroy]
        required: true

permissions:
  contents: read
  id-token: write   # needed for OIDC login

jobs:
  bootstrap:
    if: inputs.action == 'bootstrap'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7

      - uses: windsorcli/action@v1
        with:
          ref: v1.0.0
          context: aws

      - uses: windsorcli/action/cloud-auth@v1
        with:
          aws-role-arn: ${{ vars.AWS_ROLE_ARN }}
          aws-region: ${{ vars.AWS_REGION }}

      - uses: windsorcli/action/bootstrap@v1
        with:
          platform: aws
          blueprint: oci://ghcr.io/myorg/blueprint:v1.0.0
          yes: true

  destroy:
    if: inputs.action == 'destroy'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7

      - uses: windsorcli/action@v1
        with:
          ref: v1.0.0
          context: aws

      - uses: windsorcli/action/cloud-auth@v1
        with:
          aws-role-arn: ${{ vars.AWS_ROLE_ARN }}
          aws-region: ${{ vars.AWS_REGION }}

      - uses: windsorcli/action/destroy@v1
        with:
          confirm: aws
```

The action repo's own [`examples/bootstrap-and-destroy.yaml`](https://github.com/windsorcli/action/blob/main/examples/bootstrap-and-destroy.yaml) extends this to a matrix running all four cloud platforms in one workflow.

## Security

The root action masks secrets automatically: it scans `windsor.yaml` for `${{ }}`-templated environment variables, registers their values with GitHub's built-in log masking, and logs only variable names, never values. It calls out to [`actions/github-script`](https://github.com/actions/github-script) with a pinned SHA rather than a mutable tag, to keep that surface minimal.

That covers what the action does — it doesn't cover the workflow you write around it. Pin every third-party action by commit SHA, not a mutable tag (`actions/checkout@<sha> # v7`, not `@v7`), and do your own threat modeling for the systems a workflow can reach. See [GitHub's security hardening guide](https://docs.github.com/en/actions/security-for-github-actions/security-guides/security-hardening-for-github-actions).

## See also

- [Global flags](https://www.windsorcli.dev/reference/cli/global-flags) — every flag the underlying commands accept, beyond what a sub-action exposes
- [Command model](../provisioning/workflow.md) — what `bootstrap`, `apply`, `destroy`, and `up` each actually do
- [Action repo README](https://github.com/windsorcli/action) — support-bundle collection on failure, and Terraform provider caching across runs
