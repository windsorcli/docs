---
title: Securing secrets
description: Best practices for managing secrets with Windsor.
---

This page covers the risks in handling secrets and how to mitigate them. For setup and usage, see [Secrets management](secrets-management.md).

## Risks and mitigations

### Environment exposure

Secrets injected into your environment can be exposed. Prefer injecting only development secrets and avoid relying on this mechanism in production. After production bootstrapping, rotate secrets and use a production-grade secrets store.

Use `windsor env --decrypt` so secrets are decrypted only when needed. The shell hook decrypts for the session; if you run `windsor env` to inspect variables, cached secrets are omitted or shown as `********`.

### Automatic scrubbing

Windsor scrubs registered secrets from command output. Values from SOPS or 1Password are registered for scrubbing; output from commands run by Windsor (for example, Terraform) is sanitized before display. Any registered value in stdout/stderr or error messages is replaced with `********`.

### Marking values sensitive

A custom facet or context [schema](../blueprints/schema.md) property can be marked `sensitive: true`. Windsor redacts that value's path as `<sensitive>` wherever config is displayed (currently `windsor show values`) and rejects any blueprint substitution that would render it into a plaintext ConfigMap. It doesn't change how the value is stored or resolved, only how it's shown back to the operator. To land a sensitive value in a cluster as a Kubernetes Secret instead of a substitution, see [Kubernetes Secrets on Flux systems](../blueprints/facets.md#kubernetes-secrets).

## Best practices

- **Limit environment injection**: avoid injecting production secrets into your shell outside of controlled cases.
- **Rotate secrets**: rotate regularly; a central store (for example, 1Password) simplifies this.
- **Short-lived shells**: use shells only for the task at hand and close them when done to reduce exposure.
