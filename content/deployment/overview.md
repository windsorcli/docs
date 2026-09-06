---
title: Deployment overview
description: Stand up a Windsor stack on a real target — a cloud account, a virtualized platform, or bare metal — and manage its secrets.
---

Deployment covers standing up a Windsor stack on infrastructure you keep: a cloud account, a virtualized platform, or bare metal you own. These are **non-workstation contexts**: staging, production, and anything that targets real infrastructure rather than a local VM. For the local-development path, see the [Workstation overview](../workstation/overview.md).

## The deployment model

Every target follows the same lifecycle. The verbs differ from local development because there is no VM to start or stop:

```bash
windsor init production --platform aws   # scaffold the context
windsor bootstrap production             # first run: backend, infrastructure, blueprint (waits by default)
# ... day-2 reconciles ...
windsor apply --wait
# ... teardown ...
windsor destroy --confirm=production
```

`bootstrap` handles the first run end to end, including the chicken-and-egg case where the Terraform state backend (an S3 bucket, an Azure storage account) is itself created by Terraform. After the first run, `apply` reconciles changes and `destroy` removes the live infrastructure. See [Lifecycle](../contexts/lifecycle.md) for how each command fits together.

## Platforms

- [AWS](aws.md) — EKS-backed clusters with an S3 state backend.
- [Azure](azure.md) — AKS-backed clusters with an `azurerm` state backend.
- [Hetzner](hetzner.md) — Talos on Hetzner Cloud servers.
- [Hyper-V](hyperv.md) — Talos on a Windows host, host-only or LAN-bridged.
- [vSphere](vsphere.md) — Talos on existing VMware inventory.
- [Metal](metal.md) — Talos on bare metal or on-prem.

The `--platform` flag drives sensible defaults for each target, including the Terraform backend type. See [Contexts](../contexts/overview.md) for how platforms map to backends.

## Capabilities

Independent of platform, `core` composes optional capabilities you turn on with their own config:

- [Identity](identity.md) — cluster single sign-on, hosted Keycloak or an external OIDC issuer.

More land here as they get their own guide (database, gateway, observability, storage). For the full mechanism and every field, see the [Catalog](https://www.windsorcli.dev/catalog/core).

## Secrets

- [Secrets management](secrets-management.md) — SOPS and 1Password integration.
- [Securing secrets](securing-secrets.md) — handling sensitive values safely.

## Where to next

- [Contexts](../contexts/overview.md) — workstation vs non-workstation, switching contexts
- [Blueprints](../blueprints/overview.md) — what gets deployed and how it is composed
