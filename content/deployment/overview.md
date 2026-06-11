---
title: Deployment overview
description: Stand up a Windsor stack on a real target — AWS, Azure, or bare metal — and manage its secrets.
---

Deployment covers standing up a Windsor stack on infrastructure you keep: a cloud account, a virtualized platform, or bare metal you own. These are **non-workstation contexts** — staging, production, and anything that targets real infrastructure rather than a local VM. For the local-development path, see the [Workstation overview](/workstation/overview).

## The deployment model

Every target follows the same lifecycle. The verbs differ from local development because there is no VM to start or stop:

```bash
windsor init production --platform aws   # scaffold the context
windsor bootstrap production --wait      # first run: backend, infrastructure, blueprint
# ... day-2 reconciles ...
windsor apply --wait
# ... teardown ...
windsor destroy --confirm=production
```

`bootstrap` handles the first run end to end, including the chicken-and-egg case where the Terraform state backend (an S3 bucket, an Azure storage account) is itself created by Terraform. After the first run, `apply` reconciles changes and `destroy` removes the live infrastructure. See [Lifecycle](/contexts/lifecycle) for how each command fits together.

## Platforms

- [AWS](/deployment/aws) — EKS-backed clusters with an S3 state backend.
- [Azure](/deployment/azure) — AKS-backed clusters with an `azurerm` state backend.
- [Metal](/deployment/metal) — Talos on bare metal or on-prem.

The `--platform` flag drives sensible defaults for each target, including the Terraform backend type. See [Contexts](/contexts/overview) for how platforms map to backends.

## Secrets

- [Secrets management](/deployment/secrets-management) — SOPS and 1Password integration.
- [Securing secrets](/deployment/securing-secrets) — handling sensitive values safely.

## Where to next

- [Contexts](/contexts/overview) — workstation vs non-workstation, switching contexts
- [Blueprints](/blueprints/overview) — what gets deployed and how it is composed
