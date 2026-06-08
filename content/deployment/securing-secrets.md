---
title: Securing secrets
description: Best practices for managing secrets with Windsor.
---

Windsor provides features and patterns for handling secrets safely. For setup and usage see [Secrets management](/deployment/secrets-management).

## Risks and mitigations

### Environment exposure

Secrets injected into your environment can be exposed. Prefer injecting only development secrets and avoid relying on this mechanism in production. After production bootstrapping, rotate secrets and use a production-grade secrets store.

Use `windsor env --decrypt` so secrets are decrypted only when needed. The shell hook decrypts for the session; if you run `windsor env` to inspect variables, cached secrets are omitted or shown as `********`.

### Automatic scrubbing

Windsor scrubs registered secrets from command output. Values from SOPS or 1Password are registered for scrubbing; output from commands run by Windsor (for example, Terraform) is sanitized before display. Any registered value in stdout/stderr or error messages is replaced with `********`.

## Best practices

- **Limit environment injection** — Avoid injecting production secrets into your shell outside of controlled cases.
- **Rotate secrets** — Rotate regularly; a central store (for example, 1Password) simplifies this.
- **Short-lived shells** — Use shells only for the task at hand and close them when done to reduce exposure.
