---
title: Build ID
description: Generate image tags for local registry pushes and dev workflows.
---

The **build ID** is a CLI-generated identifier (format `YYMMDD.RANDOM.#`) used as image tags when pushing to a local registry and deploying to a cluster. It applies on any [workstation](overview.md) setup that provides a local registry (Docker Desktop, Colima + Docker, Colima + Incus).

## Commands

```bash
windsor build-id                    # print current build ID
windsor build-id --new              # generate a new ID
```

## Workflow

Generate a new ID, build and tag your image with it, then push to the project's local registry (`REGISTRY_URL` is set automatically in workstation contexts):

```bash
BUILD_ID=$(windsor build-id --new)
docker build -t ${REGISTRY_URL}/myapp:$BUILD_ID .
docker push ${REGISTRY_URL}/myapp:$BUILD_ID
```

Reference `${BUILD_ID}` in your Kubernetes manifests or Kustomize rather than hard-coding the tag — a fresh install picks up whichever build ID was pushed most recently and substitutes it in, so dev iterations don't require manifest edits. This keeps iterations traceable and avoids overwriting a shared `:latest` in the local registry.
