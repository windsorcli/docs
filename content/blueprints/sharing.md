---
title: Sharing blueprints
description: Push to OCI, bundle blueprints, CLI version compatibility.
---

Windsor shares blueprints through **OCI-compatible registries**. GHCR and ECR are tested; other registries that implement the OCI distribution spec (Docker Hub, Quay, your own) typically work but aren't part of the test matrix.

## Pushing to OCI

Authenticate, then push:

```bash
docker login ghcr.io
# ECR: aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account>.dkr.ecr.us-east-1.amazonaws.com
# Docker Hub: docker login docker.io
```

```bash
windsor push ghcr.io/myorg/myblueprint:v1.0.0
windsor push <account>.dkr.ecr.us-east-1.amazonaws.com/myblueprint:v1.0.0
windsor push registry.example.com/blueprints   # uses metadata.yaml name/version
```

OCI URLs: `oci://registry/repository:tag`. In blueprint sources use the full form, for example, `oci://ghcr.io/windsorcli/core:v0.6.0`.

## Using shared blueprints

Reference OCI blueprints in your blueprint sources:

```yaml
sources:
  - name: shared-blueprint
    url: oci://ghcr.io/myorg/myblueprint:v1.0.0
    deploy: true   # default for OCI sources; set false to reference without merging components
```

Windsor downloads the artifact, extracts the template, processes [facets](/blueprints/facets), and validates config and CLI version. OCI sources with `deploy: true` (default) have their Terraform and Kustomize components merged; with `deploy: false` the blueprint is index-only — components elsewhere can reference it via `source: <name>` but its own components don't get merged. See [Blueprint templates — Composition order](/blueprints/templates#composition-order).

## Bundling

Package a blueprint for pushing to OCI:

```bash
windsor bundle -t myapp:v1.0.0
windsor bundle -t myapp:v1.0.0 -o ./dist/
windsor bundle   # uses metadata.yaml name/version
```

The bundle includes everything under `contexts/_template/` and, when present, local `terraform/` and `kustomize/` directories. External sources (Git, OCI) are not bundled; they are resolved when the blueprint is used.

## Artifact structure

OCI artifacts use the following layout:

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

Set `cliVersion` in `contexts/_template/metadata.yaml` so users get a clear error if their CLI is too old:

```yaml
name: my-blueprint
version: 1.0.0
cliVersion: ">=0.9.0"
```

Common patterns: `">=0.9.0"`, `"~0.9.0"`, `">=0.9.0 <0.10.0"`. Always quote — unquoted `>` and `<` are YAML control characters. Validation runs when loading from OCI or a local archive — see the [metadata reference](/reference/cli/metadata) for the full field set.

## Best practices

1. Version blueprints with semantic tags (for example, `v1.0.0`).
2. Include `metadata.yaml` with `name` and `cliVersion`.
3. Set `cliVersion` when using features that need a minimum CLI version.
4. Test locally and at the minimum specified CLI version before sharing.
