---
title: Overview
description: Put secret() references in Terraform inputs, values.yaml, .env files, or Kubernetes Secrets. Learn when Windsor decrypts them and where the values go.
---

- config files are in git; a plaintext credential in `values.yaml` or `blueprint.yaml` gets committed (problem; no claim)
- the file holds a `secret()` reference; the value stays in a secret store (live, claim 1)
- resolved only by commands that ask for values (live, claims 11–14)
- never written back to a file, `terraform.tfvars` included (live, claim 16)
- two providers: SOPS, encrypted files in the context; 1Password, vault items (live, claims 2–3)
- one context can use both (live, claim 30)

## Write a reference

- form: `${secret("<vault>", "<item>", "<field>")}` (live, claim 1)
- 2 or 3 string arguments (live, claim 1)
- vault `sops`, any case: item is the dot-path of a key (live, claim 2)
- SOPS third argument joined to the item with a dot: `"database.admin", "user"` reads `database.admin.user` (live, claim 2; optional detail)
- any other vault: a key under `secrets.onepassword.vaults`; third argument, the field label, required (live, claim 3)
- the first provider that owns the vault resolves the reference (live, claim 4)
- no owner: `No secrets provider handles the vault "<vault>".` (live, claim 4)
- wrong argument count: `The secret() helper takes 2 or 3 arguments, but the call has <n>.` (source, error table)
- SOPS enabled and each 1Password vault declared in `values.yaml`: link the provider pages (live, SOPS claim 1, 1Password claim 1)

## Where to use a secret

- five places, one consumer each (claims 5–8, 27)

### Terraform inputs

- component `inputs:` in `blueprint.yaml` (live, claim 5)
- `plan` and `apply` pass the input as `TF_VAR_<input>` (live, claim 5)
- hook sets `TF_VAR_<input>` inside `terraform/<module>`, unsets it at the root (live, Commands: Hook in and out of a module folder)
- link for the hook: `../contexts/environment-injection.md#set-up-the-shell-hook`

### Values in values.yaml

- a credential property takes a reference as its value (source, claim 6)
- core marks `hetzner.token` `sensitive: true` (source, claim 6, core `contexts/_template/schema.yaml:432-435`)
- the blueprint passes the value to the components that read the property (source, claim 6)
- `windsor show values` printed the reference as written, not `<sensitive>` (live, Known problems)

### Provider credentials in terraform/.env

- providers read credentials from env vars: `HCLOUD_TOKEN`, `VSPHERE_PASSWORD` (live, claim 7)
- file: `contexts/<context>/terraform/.env` (live, claim 7)
- exported to Terraform in `plan` and `apply`; to the shell only inside a module folder (live, claim 7)
- the file holds references, so a team can share it; each person's SOPS key or 1Password sign-in supplies the values (follows from claims 2–3)
- `contexts/<context>/.gitignore` ignores `.env`, which also matches `terraform/.env` (live, claim 9)
- `!terraform/.env` in that `.gitignore` to commit it (follows from claim 9; not run)
- macOS and Linux: warning when group or other can read a `.env` (live, claim 10)
- `chmod 600` clears it; no check on Windows (live, claim 10)

### Shell environment

- `environment:` in `values.yaml` and `contexts/<context>/.env` reach every shell in the context (live, claim 8)
- hook resolves each reference at the first prompt of a new shell (live, claim 14)
- every process started from that shell can read the value (live, claim 12: `exec` child saw a 64-character token)
- each 1Password reference is one `op` call; many references slow the first prompt (source, 1Password claim 11)

### Kubernetes Secrets

- `flux:` system's `secrets:` block (source, claim 27)
- each entry a Kubernetes Secret whose `data` values are references (source, claim 27)
- resolved at apply time, never written to a file (source, claim 27)
- link: `../blueprints/facets.md#kubernetes-secrets`

### Kustomize substitutions

- Windsor writes substitutions to a ConfigMap, plain text (live, claim 26)
- a facet substitution that references a `sensitive` property is rejected (source, claim 26)
- a `secret()` call in a substitution is not checked; it lands in the ConfigMap as written (live, claim 26)
- a top-level `substitutions:` entry in the context's `blueprint.yaml` was not rejected (live, Known problems)

## Under the hood

- diagram: config files → Windsor command → secret stores → Terraform process and shell; `terraform.tfvars` gets no value (Prepared blocks)

### When Windsor decrypts

- composition leaves each `secret()` call as written; `windsor show blueprint` prints the reference (live, claim 15)
- `plan`, `apply`, `up`, `destroy`, `bootstrap`, `install`: every reference in the context (live, claim 13)
- every reference means inputs, `terraform/.env`, `environment:`, and `contexts/<context>/.env`; the Terraform process sees all of them (live, claim 13, phase 1b)
- `windsor exec`: always decrypts `environment:` and `.env` for the child (live, claim 12)
- the hook runs `windsor env --decrypt --hook` at each prompt (live, claim 14)
- the hook resolves `environment:` and `.env`; inside a module folder also that component's inputs and `terraform/.env` (live, claim 14)
- `windsor env`: `********` per reference; `windsor env --decrypt`: the value (live, claim 11)
- `up` and `bootstrap` resolve every Kubernetes Secret's references before the first Terraform apply; a missing item stops the run before any change (source, claim 28; not in v0.10.0)
- Terraform commands check 1Password access first: link `1password.md#check-access-before-a-run` (live, claim 29)

### Where the value goes

- generated `.windsor/contexts/<context>/terraform/<module>/terraform.tfvars` never holds the value (live, claim 16)
- module declares `sensitive = true`: `# <name> = "(sensitive)"`; otherwise `# <name> = null` (live, claim 16)
- Terraform receives `TF_VAR_<name>` for the length of the run (live, claim 5)
- a resource that uses the value puts it in Terraform state (live, claim 19)
- default local backend: `.windsor/contexts/<context>/.tfstate/<module>/terraform.tfstate` (live, claim 19)
- keep state in an encrypted backend (advice; no claim)
- SOPS: decrypted in memory, through the SOPS library (source, claim 31)
- 1Password: the `op` CLI or the SDK returns the value to Windsor (source, claim 31)

### Caching

- the hook keeps each resolved value in the shell; no provider call at later prompts (live, claim 20)
- covers `environment:`, `.env`, `terraform/.env`, a component's `TF_VAR_` variables (source, claim 21)
- a new shell resolves everything again (live, claim 20)
- after a change, an open shell keeps the old value (live, claim 20: `example-password` after the `sops` edit)
- `NO_CACHE=1` or `NO_CACHE=true` for one prompt fetches again (live, claim 20)
- `windsor exec` and `windsor env` without `--hook` never use the cache; they set `NO_CACHE=true` when unset (live, claim 22)
- a variable that failed holds an error marker; the hook retries it at every prompt (live, claim 23)
- a provider slow to fail slows every prompt (follows from claim 23)

### Masking

- each resolved value becomes `********` in printed output: plans, applies, error messages, `exec` output (live, claims 12, 17)
- exact match only; a base64 encoding of the value printed in full (live, claim 17)
- provider values masked at any length; plain `.env` values have a length floor (source, claim 18)
- do not rely on masking alone (advice; follows from claim 17)

## Troubleshooting

- a failed reference leaves `<ERROR: ...>` in its variable (live, claim 23)
- find markers: `env | grep '<ERROR'` (live, claim 24)
- PowerShell: `Get-ChildItem Env: | Where-Object { $_.Value -like '*<ERROR*' }` (not run; from the old page)
- the hook prints no errors, so a broken project cannot break the prompt (live, claim 25: 0 bytes, exit 0)
- `windsor env --decrypt` prints markers with the error text (live, claim 25)
- a failure that stops the whole command prints `error:` and `hint:` and exits 1, with or without `--verbose` (live, claim 25)
- `--verbose` adds the failing expression and a caret (live, claim 25)

## Choosing a provider

- SOPS: secrets in the repository, encrypted; versioned and reviewed like any file; no external service (live, SOPS claims 3, 9)
- 1Password: vaults the team already manages; rotate by editing the item (live, 1Password claim 4)
- one context can use both (live, claim 30)
- links: `sops.md`, `1password.md`
