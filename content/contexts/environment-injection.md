---
title: Environment injection
description: Windsor sets KUBECONFIG, your cloud profile, and Terraform variables for the active context, through a shell hook or windsor exec.
---

`kubectl`, `terraform`, and the cloud CLIs read their configuration from environment variables. Windsor sets those variables for the active [context](overview.md) so each tool targets the right cluster and account. You can apply them to a single command with [`windsor exec`](https://www.windsorcli.dev/reference/cli/commands/exec), or install a [shell hook](#set-up-the-shell-hook) that keeps them current on every prompt. It works like [direnv](https://github.com/direnv/direnv), except the variables follow the active context instead of the current directory.

## Run a command with `windsor exec`

`windsor exec` runs one command with the active context's environment and decrypted secrets. It uses the active context unless you pass `--context`:

```bash
windsor exec -- kubectl get pods
windsor exec --context staging -- kubectl get pods
```

## Set up the shell hook

To run plain `kubectl` and `terraform` without `windsor exec`, install the shell hook. It sets the environment for the active context at every prompt. Add the line for your shell to its startup file, then open a new shell.

Windsor supports zsh, bash, and PowerShell. Pick the tab for the shell you run, whatever the operating system.

<!-- tabs -->

<!-- tab:zsh -->

For zsh, add this line to `~/.zshrc`:

```bash
eval "$(windsor hook zsh)"
```

<!-- tab:bash -->

For bash, add this line to `~/.bashrc`:

```bash
eval "$(windsor hook bash)"
```

On macOS, Terminal starts bash as a login shell, which reads `~/.bash_profile` instead. Put the line there.

<!-- tab:powershell -->

For PowerShell, add the hook to your profile. The first command creates the profile if you don't have one:

```powershell
if (!(Test-Path $PROFILE)) { New-Item -ItemType File -Path $PROFILE -Force }
Add-Content $PROFILE 'windsor hook powershell | Out-String | Invoke-Expression'
```

<!-- /tabs -->

After that, [`windsor set context <name>`](https://www.windsorcli.dev/reference/cli/commands/set) updates the environment on your next prompt.

The hook decrypts secret references in `environment` and `.env`, so many references slow the first prompt of a new shell. See [When Windsor decrypts](../secrets/overview.md#when-windsor-decrypts).

## What changes when you switch

[`windsor set context staging`](https://www.windsorcli.dev/reference/cli/commands/set) changes the active context. On the next prompt the hook unsets the old context's variables and sets staging's, including `KUBECONFIG` and the cloud profile. Nothing is merged.

Windsor injects only in trusted directories, and in an untrusted one it does nothing, even to clear what the last prompt set. If you `cd` from a trusted project into an untrusted directory, the old `KUBECONFIG` stays set until you `cd` somewhere trusted. See [Trusted folders](trusted-folders.md).

Windsor treats a directory as part of a project when a `windsor.yaml` sits in it or in a parent. Outside a project, Windsor runs in global mode. The shell hook prints nothing there. `windsor env` and `windsor exec` still work, with `~/.config/windsor` as the project root, but they leave out the cloud variables that point at project files, such as `AWS_CONFIG_FILE` and `AWS_SHARED_CREDENTIALS_FILE`.

## Terraform folders and tfvars

Your modules live in the project's `terraform/` folder, shared by every context. Each context keeps its own values for them in `contexts/<name>/terraform/`, in a tree that mirrors the module paths:

```text
terraform/                        # modules, shared by every context
├── cluster/
│   └── main.tf
└── net/
    └── vpc/
        └── main.tf
contexts/
└── staging/
    └── terraform/                # this context's values
        ├── cluster.tfvars        # for terraform/cluster
        └── net/
            └── vpc.tfvars        # for terraform/net/vpc
```

When you `cd` into a module, Windsor adds the matching tfvars file to the arguments Terraform reads from the environment. A `terraform plan` run by hand there uses the same values as [`windsor plan terraform`](https://www.windsorcli.dev/reference/cli/commands/plan):

```bash
cd terraform/cluster
terraform plan        # picks up contexts/staging/terraform/cluster.tfvars
```

Terraform reads the file through `TF_CLI_ARGS_plan`, and Windsor sets the same `-var-file` for `destroy`, `import`, and `refresh`. It passes two files: the `terraform.tfvars` that Windsor generates under `.windsor/`, then yours. Terraform applies later files last, so a value in yours overrides the same variable in the generated file. A `.tfvars.json` file works too. Staging and production each have their own `cluster.tfvars` for the same module.

Windsor also sets `TF_VAR_context`, `TF_VAR_context_id`, `TF_VAR_context_path`, `TF_VAR_project_root`, and `TF_VAR_os_type`. Declare variables with those names in a module to read them.

`TF_CLI_ARGS_init` carries the context's backend settings, so a manual `terraform init` uses the right backend. In a folder that a blueprint [component](../components/terraform.md) points at with `path:`, Windsor also writes a `backend_override.tf` and adds it to `terraform/.gitignore`. See [Lifecycle](../provisioning/state-backend.md#bootstrap) for how `bootstrap` creates and migrates that backend.

Variables in `contexts/<name>/terraform/.env` are exported only inside these module directories, which makes it the place for credentials Terraform needs and nothing else should see. Values can be [secret references](../secrets/overview.md#provider-credentials-in-terraformenv).

## Under the hood

On every prompt the hook runs [`windsor env --hook`](https://www.windsorcli.dev/reference/cli/commands/env) and your shell evaluates what it prints. Each shell attaches differently:

| Shell | Runs the hook |
|---|---|
| zsh | Before each prompt (`precmd`) and when you change directory (`chpwd`) |
| bash | Before each prompt, through `PROMPT_COMMAND`, preserving the last command's exit status |
| PowerShell | In a wrapper around your existing `prompt` function, which still runs afterward |

`WINDSOR_MANAGED_ENV` lists the variables Windsor set, and the hook unsets that list before applying a new context's. The `--hook` flag makes `env` non-fatal: warnings are suppressed and errors exit 0, so a broken project can't break your prompt. In an untrusted project or outside any project, it prints nothing. Run `windsor env --verbose` without `--hook` to see the full output and any errors. Without `--verbose`, a failing `windsor env` prints nothing.

In a fresh `local` context, `windsor env` prints:

```text
$ windsor env
DOCKER_CONFIG=/Users/me/.config/windsor/docker
DOCKER_HOST=unix:///Users/me/.docker/run/docker.sock
FLUX_SYSTEM_NAMESPACE=system-gitops
K8S_AUTH_KUBECONFIG=/path/to/project/contexts/local/.kube/config
KUBECONFIG=/path/to/project/contexts/local/.kube/config
KUBE_CONFIG_PATH=/path/to/project/contexts/local/.kube/config
TALOSCONFIG=/path/to/project/contexts/local/.talos/config
WINDSOR_CONTEXT=local
WINDSOR_CONTEXT_ID=wrk3va8i
WINDSOR_MANAGED_ALIAS=
WINDSOR_MANAGED_ENV=DOCKER_HOST,DOCKER_CONFIG,KUBECONFIG,KUBE_CONFIG_PATH,K8S_AUTH_KUBECONFIG,FLUX_SYSTEM_NAMESPACE,TALOSCONFIG,WINDSOR_CONTEXT,WINDSOR_CONTEXT_ID,WINDSOR_PROJECT_ROOT,WINDSOR_SESSION_TOKEN,WINDSOR_MANAGED_ENV,WINDSOR_MANAGED_ALIAS
WINDSOR_PROJECT_ROOT=/path/to/project
WINDSOR_SESSION_TOKEN=ldC26Dp
```

Cloud provider variables appear when the matching config block is present. Terraform variables appear when you're inside a component's directory. See [Terraform folders and tfvars](#terraform-folders-and-tfvars).

## Reference

For every variable Windsor sets per tool, and which of them global mode leaves out, run [`windsor env`](https://www.windsorcli.dev/reference/cli/commands/env) in the context you care about.

- [`windsor env`](https://www.windsorcli.dev/reference/cli/commands/env), [`windsor exec`](https://www.windsorcli.dev/reference/cli/commands/exec), [`windsor hook`](https://www.windsorcli.dev/reference/cli/commands/hook)
- [Trusted folders](trusted-folders.md)
- [Terraform components](../components/terraform.md)
