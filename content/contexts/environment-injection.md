---
title: Environment injection
description: Windsor sets KUBECONFIG, your cloud profile, and Terraform variables for the active context, through a shell hook or windsor exec.
---

`kubectl`, `terraform`, and the cloud CLIs read their configuration from environment variables. Windsor sets those variables for the active [context](overview.md) so each tool targets the right cluster and account. You can apply them to a single command with [`windsor exec`](https://www.windsorcli.dev/reference/cli/commands/exec), or install a [shell hook](#set-up-the-shell-hook) that keeps them current on every prompt. It works like [direnv](https://github.com/direnv/direnv), except the variables follow the active context instead of the current directory.

## Run a command with `windsor exec`

`windsor exec` runs one command with the active context's environment and decrypted secrets,

```bash
windsor exec -- kubectl get pods
windsor exec --context staging -- kubectl get pods
```

The command executes against your current context. You may also set the context explicitly by passing in `--context`.

## Set up the shell hook

If you'd rather drop `windsor exec` and always run commands against the active context, you should configure the shell hook. The hook sets the appropriate environment on every prompt, so plain `kubectl` and `terraform` commands always target the active context. Add it to your shell's startup file, then open a new shell.

<!-- tabs -->

<!-- tab:macos -->

On macOS, zsh is the default shell. Add this line to `~/.zshrc`:

```bash
eval "$(windsor hook zsh)"
```

If you use bash instead, add `eval "$(windsor hook bash)"` to `~/.bash_profile`, because Terminal starts bash as a login shell.

<!-- tab:linux -->

On Linux, add this line to `~/.bashrc` for bash:

```bash
eval "$(windsor hook bash)"
```

For zsh, add `eval "$(windsor hook zsh)"` to `~/.zshrc`.

<!-- tab:windows -->

On Windows, add the hook to your PowerShell profile. The first command creates the profile if you don't have one:

```powershell
if (!(Test-Path $PROFILE)) { New-Item -ItemType File -Path $PROFILE -Force }
Add-Content $PROFILE 'windsor hook powershell | Out-String | Invoke-Expression'
```

<!-- /tabs -->

After that, [`windsor set context <name>`](https://www.windsorcli.dev/reference/cli/commands/set) updates the environment on your next prompt.

## What changes when you switch

[`windsor set context staging`](https://www.windsorcli.dev/reference/cli/commands/set) changes the active context. On the next prompt the hook unsets the old context's variables and sets staging's, including `KUBECONFIG` and the cloud profile. Nothing is merged.

Windsor injects only in trusted directories, and in an untrusted one it does nothing, even to clear what the last prompt set. If you `cd` from a trusted project into an untrusted directory, the old `KUBECONFIG` stays set until you `cd` somewhere trusted. See [Trusted folders](trusted-folders.md).

Inside a project, meaning a directory with a `windsor.yaml` above it, you get the full environment. Outside one, Windsor runs in global mode. It still sets the variables that say which cluster or account to use, but it leaves out the ones that point a tool at a project-local config or credentials file, so it doesn't override your own setup.

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

When a blueprint [component](../components/terraform.md) points at one of these modules with `path:`, `cd` into the module and Windsor adds the matching tfvars file to the arguments Terraform reads from the environment. A `terraform plan` run by hand there uses the same values as [`windsor plan terraform`](https://www.windsorcli.dev/reference/cli/commands/plan):

```bash
cd terraform/cluster
terraform plan        # picks up contexts/staging/terraform/cluster.tfvars
```

Terraform reads the file through `TF_CLI_ARGS_plan`, and Windsor sets the same `-var-file` for `destroy`, `import`, and `refresh`. A `.tfvars.json` file works too. Staging and production each keep their own `cluster.tfvars`, so the module stays the same and only the values change.

Windsor also sets `TF_VAR_context`, `TF_VAR_context_id`, `TF_VAR_context_path`, `TF_VAR_project_root`, and `TF_VAR_os_type`, so a module can declare variables with those names and use them. The `TF_CLI_ARGS_init` setting carries the context's backend configuration, which is how a manual `terraform init` ends up using the right backend. The first time you enter a module folder, Windsor also writes a git-ignored `backend_override.tf` there so the module points at that backend. See [Lifecycle](../provisioning/workflow.md#under-the-hood) for how `bootstrap` creates and migrates that backend.

Variables in `contexts/<name>/terraform/.env` are exported only inside these module directories, which makes it the place for credentials Terraform needs and nothing else should see.

## Under the hood

On every prompt the hook runs [`windsor env --hook`](https://www.windsorcli.dev/reference/cli/commands/env) and your shell evaluates what it prints. Each shell attaches differently:

| Shell | Runs the hook |
|---|---|
| zsh | Before each prompt (`precmd`) and when you change directory (`chpwd`) |
| bash | Before each prompt, through `PROMPT_COMMAND`, preserving the last command's exit status |
| PowerShell | In a wrapper around your existing `prompt` function, which still runs afterward |

`WINDSOR_MANAGED_ENV` lists the variables Windsor set, and the hook unsets that list before applying a new context's. The `--hook` flag makes `env` non-fatal: warnings are suppressed and errors exit 0, so a broken project can't break your prompt. Run `windsor env` without it to see the full output and any errors.

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
WINDSOR_MANAGED_ENV=DOCKER_HOST,DOCKER_CONFIG,KUBECONFIG,KUBE_CONFIG_PATH,TALOSCONFIG,FLUX_SYSTEM_NAMESPACE,K8S_AUTH_KUBECONFIG,WINDSOR_CONTEXT,WINDSOR_CONTEXT_ID,WINDSOR_PROJECT_ROOT,WINDSOR_SESSION_TOKEN
WINDSOR_MANAGED_ALIAS=
WINDSOR_PROJECT_ROOT=/path/to/project
WINDSOR_SESSION_TOKEN=ldC26Dp
```

Cloud provider variables appear when the matching config block is present. Terraform variables appear when you're inside a component's directory. See [Terraform folders and tfvars](#terraform-folders-and-tfvars).

## Reference

For every variable Windsor sets per tool, and which of them global mode leaves out, run [`windsor env`](https://www.windsorcli.dev/reference/cli/commands/env) in the context you care about.

- [`windsor env`](https://www.windsorcli.dev/reference/cli/commands/env), [`windsor exec`](https://www.windsorcli.dev/reference/cli/commands/exec), [`windsor hook`](https://www.windsorcli.dev/reference/cli/commands/hook)
- [Trusted folders](trusted-folders.md)
- [Terraform components](../components/terraform.md)
