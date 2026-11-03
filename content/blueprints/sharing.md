---
title: Registries
description: Push a blueprint to an OCI registry, consume it from another project, and set the CLI versions it supports.
---

A template that serves every context in one project often fits a second project too. Copying `contexts/_template/` into the second project works once, but the two copies drift apart with every change. Windsor publishes a blueprint as an *OCI artifact*, a package in the format that container registries store, so any registry that holds images can hold a blueprint. [`windsor push`](https://www.windsorcli.dev/reference/cli/commands/push) builds the artifact from `contexts/_template/` and pushes it, and other projects add its `oci://` URL to their blueprint sources. `core` itself is published this way, at `oci://ghcr.io/windsorcli/core:v0.8.0`.

## Pushing to OCI

Windsor pushes with your Docker credentials, so log in to the registry first. These commands log in to GitHub Container Registry, Amazon ECR, or Docker Hub.

```bash
docker login ghcr.io
# ECR: aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account>.dkr.ecr.us-east-1.amazonaws.com
# Docker Hub: docker login docker.io
```

Then push, either with a tag in the reference or without one, in which case Windsor takes the name and version from `metadata.yaml`.

```bash
windsor push ghcr.io/<org>/<blueprint>:v1.0.0
windsor push <account>.dkr.ecr.us-east-1.amazonaws.com/<blueprint>:v1.0.0
windsor push registry.example.com/blueprints   # uses metadata.yaml name/version
```

In blueprint sources, an OCI URL takes the full form `oci://<registry>/<repository>:<tag>`, for example `oci://ghcr.io/windsorcli/core:v0.8.0`.

## Using shared blueprints

A context consumes a shared blueprint by listing its URL under `sources:` in its `blueprint.yaml`. This entry adds a blueprint that the `<org>` organization pushed.

```yaml
sources:
  - name: shared-blueprint
    url: oci://ghcr.io/<org>/<blueprint>:v1.0.0
    install: true   # default for OCI sources; set false to reference without merging components
```

Windsor downloads the artifact, extracts the template, processes its [facets](facets.md), and validates the config and the CLI version. For an OCI source with `install: true`, which is the default, Windsor merges the blueprint's Terraform and Kustomize components into the context's blueprint. With `install: false` the blueprint is index-only. Components elsewhere can reference it through `source: <name>`, but Windsor merges none of its own components. [The _template folder — Composition order](templates.md#composition-order) gives the order in which sources merge.

## Caching and private registries

Windsor caches downloaded artifacts on disk and reuses them across commands, so it fetches a blueprint once rather than on every `init`, `up`, or `apply`. `--no-cache` is a persistent flag that bypasses the cache for one run of any command. This run of `windsor up` downloads its artifacts again.

```bash
windsor up --no-cache
```

Windsor pulls from a private registry with your Docker credential chain, the same logins that `docker login` writes. After one login, Windsor reuses the keychain entry, and it reads public registries anonymously. After this login, private `oci://` sources on `ghcr.io` resolve.

```bash
docker login ghcr.io
```

## Bundling

`windsor bundle` packages a blueprint without pushing it. These commands set the tag, write the bundle to `./dist/`, or take the name and version from `metadata.yaml`.

```bash
windsor bundle -t <blueprint>:v1.0.0
windsor bundle -t <blueprint>:v1.0.0 -o ./dist/
windsor bundle   # uses metadata.yaml name/version
```

The bundle includes everything under `contexts/_template/` and, when present, the project's local `terraform/` and `kustomize/` directories. Windsor leaves out external sources such as Git and OCI blueprints, and resolves them when the blueprint is used.

## Artifact structure

A blueprint artifact has this layout.

```text
artifact/
├── metadata.yaml
├── _template/
│   ├── blueprint.yaml
│   ├── schema.yaml
│   ├── metadata.yaml
│   └── facets/
├── terraform/    # if present in project
└── kustomize/    # if present in project
```

## CLI version compatibility

A blueprint that depends on a CLI feature sets `cliVersion` in `contexts/_template/metadata.yaml`, so that a user with an older CLI gets a clear error. `core` sets `cliVersion: ">=0.10.0"`. This `metadata.yaml` also sets the name and version that `windsor push` and `windsor bundle` use when the command has no tag.

```yaml
name: my-blueprint
version: 1.0.0
cliVersion: ">=0.9.0"
```

`cliVersion` takes a version range, such as `">=0.9.0"`, `"~0.9.0"`, or `">=0.9.0 <0.10.0"`. Always quote it, because unquoted `>` and `<` are YAML control characters. Windsor checks the range when it loads the blueprint from OCI or from a local archive. The [metadata reference](https://www.windsorcli.dev/reference/cli/metadata) lists the full field set.

## Best practices

1. Version blueprints with semantic tags (for example, `v1.0.0`).
2. Include `metadata.yaml` with `name` and `cliVersion`.
3. Set `cliVersion` when using features that need a minimum CLI version.
4. Test locally and at the minimum specified CLI version before sharing.
