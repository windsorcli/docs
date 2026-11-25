---
title: Environment injection
description: Windsor sets KUBECONFIG, your cloud profile, and Terraform variables for the active context, through a shell hook or windsor exec.
---

`kubectl`, `terraform`, and the cloud CLIs each read their configuration from environment variables. `kubectl` reads `KUBECONFIG`, the AWS CLI reads `AWS_CONFIG_FILE` and `AWS_REGION`, and Terraform reads `TF_VAR_*` and `TF_CLI_ARGS_*`. Windsor sets those variables from the active [context](overview.md), so a plain `kubectl get nodes` in the `local` context reaches the `local` cluster. You can apply them to one command with `windsor exec`, or install a shell hook that keeps them current at every prompt.

## Run a command with `windsor exec`

[`windsor exec`](https://www.windsorcli.dev/reference/cli/commands/exec) runs one command with the active context's environment and its decrypted secrets:

```bash
windsor exec -- kubectl get nodes
```

To run against another context without switching, add the global `--context` flag. The active context stays the same.

```bash
windsor exec --context production -- printenv WINDSOR_CONTEXT
```

```text
production
```

## Set up the shell hook

The shell hook sets the active context's environment before each prompt, so `kubectl` and `terraform` work without `windsor exec`. Add the line for your shell to its startup file, then open a new shell.

Windsor has hooks for zsh, bash, fish, tcsh, and PowerShell. Pick the tab for the shell you run, whatever the operating system.

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

<!-- tab:fish -->

For fish, add this line to `~/.config/fish/config.fish`:

```fish
windsor hook fish | source
```

<!-- tab:tcsh -->

For tcsh, add this line to `~/.tcshrc`:

```tcsh
eval "`windsor hook tcsh`"
```

<!-- tab:powershell -->

For PowerShell, add the hook to your profile. The first command creates the profile if you don't have one:

```powershell
if (!(Test-Path $PROFILE)) { New-Item -ItemType File -Path $PROFILE -Force }
Add-Content $PROFILE 'windsor hook powershell | Out-String | Invoke-Expression'
```

<!-- /tabs -->

The hook decrypts secret references in a context's `environment:` block and `.env` file, so many references slow the first prompt of a new shell. See [When Windsor decrypts](../secrets/overview.md#when-windsor-decrypts).

## What changes when you switch

Take a project with two contexts. `local` runs on Docker and sets `GREETING: hello-local` and `ONLY_LOCAL: "1"` in the `environment:` block of its `values.yaml`. `production` runs on AWS in `us-east-1` and sets only `GREETING: hello-production`.

You switch with [`windsor set context`](https://www.windsorcli.dev/reference/cli/commands/set-context):

```bash
windsor set context production
```

At the next prompt the hook unsets every variable it set for `local`, then exports the ones for `production`. `KUBECONFIG` moves to `contexts/production/.kube/config`. `GREETING` becomes `hello-production`. `ONLY_LOCAL` is gone, because `production` does not define it. `DOCKER_HOST` and `TALOSCONFIG` are gone too, and `AWS_CONFIG_FILE`, `AWS_SHARED_CREDENTIALS_FILE`, and `AWS_REGION` appear. Nothing carries over from one context to the next.

The hook acts only inside a [trusted](trusted-folders.md) project. In an untrusted project, and in a directory outside any project, it prints nothing, even to clear what the last prompt set. If you `cd` from the project to `/tmp`, `KUBECONFIG` still points at the `local` cluster until you `cd` back.

Windsor treats a directory as part of a project when `windsor.yaml` is in it or in one of its parents. Outside a project, Windsor runs in *global mode*, with `~/.config/windsor` as the project root. The hook prints nothing there. `windsor env` and `windsor exec` still work, but leave out the cloud variables that point at project files, such as `AWS_CONFIG_FILE` and `AWS_SHARED_CREDENTIALS_FILE`.

## Terraform folders and tfvars

Your own Terraform modules live in the project's `terraform/` folder, shared by every context. Each context keeps its values for them in `contexts/<name>/terraform/`, in a tree that mirrors the module paths. This listing shows one module and the `local` context's values for it.

```text
terraform/
└── net/
    └── vpc/
        └── main.tf               # declares variable "cidr"
contexts/
└── local/
    └── terraform/
        ├── .env                  # VPC_API_TOKEN=...
        └── net/
            └── vpc.tfvars        # cidr = "10.20.0.0/16"
```

When you `cd` into `terraform/net/vpc`, the hook adds `vpc.tfvars` to the arguments Terraform reads from the environment. A `terraform plan` you run there uses the same values that [`windsor plan terraform`](https://www.windsorcli.dev/reference/cli/commands/plan-terraform) would:

```bash
cd terraform/net/vpc
terraform init
terraform plan        # cidr = "10.20.0.0/16", from contexts/local/terraform/net/vpc.tfvars
```

`terraform plan` saves its plan in Windsor's data directory for the module, and a following `terraform apply` applies that saved plan. In `production`, the same commands read `contexts/production/terraform/net/vpc.tfvars` instead.

Variables in `contexts/<name>/terraform/.env` are exported only inside module directories and unset when you leave. That makes the file the place for credentials that Terraform needs and nothing else should see. Values can be [secret references](../secrets/overview.md#provider-credentials-in-terraformenv).

## Under the hood

At each prompt the hook runs [`windsor env --decrypt --hook`](https://www.windsorcli.dev/reference/cli/commands/env), and the shell evaluates the `export` and `unset` lines it prints. Each shell attaches differently.

| Shell | Runs the hook |
|---|---|
| zsh | Before each prompt (`precmd`) and on each directory change (`chpwd`) |
| bash | Before each prompt, through `PROMPT_COMMAND`, keeping the last command's exit status |
| fish | On the `fish_prompt` event |
| tcsh | From the `precmd` alias |
| PowerShell | In a wrapper around your existing `prompt` function, which still runs afterward |

The `--hook` flag makes `env` non-fatal. It sends warnings to `/dev/null` and exits 0 on any error, so a broken project cannot break your prompt. Run `windsor env --verbose` without `--hook` to see the errors.

`WINDSOR_MANAGED_ENV` lists every variable Windsor set. `windsor set context` leaves a reset token in `.windsor/`, and on the next prompt the hook unsets everything in that list before it exports the new context's variables. On every other prompt, Windsor also unsets any name from the previous list that no part of the new environment sets, so a key removed from `environment:` disappears too.

In a fresh `local` context, `windsor env` prints:

```text
DOCKER_CONFIG=/Users/me/.config/windsor/docker
DOCKER_HOST=unix:///Users/me/.docker/run/docker.sock
FLUX_SYSTEM_NAMESPACE=system-gitops
K8S_AUTH_KUBECONFIG=/path/to/project/contexts/local/.kube/config
KUBECONFIG=/path/to/project/contexts/local/.kube/config
KUBE_CONFIG_PATH=/path/to/project/contexts/local/.kube/config
TALOSCONFIG=/path/to/project/contexts/local/.talos/config
WINDSOR_CONTEXT=local
WINDSOR_CONTEXT_ID=wa36g480
WINDSOR_MANAGED_ALIAS=
WINDSOR_MANAGED_ENV=DOCKER_HOST,DOCKER_CONFIG,KUBECONFIG,KUBE_CONFIG_PATH,K8S_AUTH_KUBECONFIG,FLUX_SYSTEM_NAMESPACE,TALOSCONFIG,WINDSOR_CONTEXT,WINDSOR_CONTEXT_ID,WINDSOR_PROJECT_ROOT,WINDSOR_SESSION_TOKEN,WINDSOR_MANAGED_ENV,WINDSOR_MANAGED_ALIAS
WINDSOR_PROJECT_ROOT=/path/to/project
WINDSOR_SESSION_TOKEN=cwornoJ
```

Cloud variables appear when the context configures that cloud. Terraform variables appear only in a directory that holds `*.tf` files under a `terraform/` folder.

### Terraform variables

In a module directory, Windsor sets these variables:

| Variable | Holds |
|---|---|
| `TF_DATA_DIR` | `.windsor/contexts/<context>/.terraform/<module>`, so each context keeps its own providers and plan |
| `TF_CLI_ARGS_init` | `-backend=true`, the context's backend settings, and `-lock-timeout` |
| `TF_CLI_ARGS_plan` | `-out` to the saved plan, the `-var-file` arguments, and `-lock-timeout` |
| `TF_CLI_ARGS_apply` | `-lock-timeout` and the saved plan |
| `TF_CLI_ARGS_refresh`, `_import`, `_destroy` | the `-var-file` arguments and `-lock-timeout` |
| `TF_VAR_context`, `TF_VAR_context_id`, `TF_VAR_context_path`, `TF_VAR_project_root`, `TF_VAR_os_type` | the context name, its `id`, `contexts/<context>`, the project root, and `unix` or `windows` |

The `-var-file` arguments come in a fixed order. When the directory is a blueprint [component](../components/terraform.md), the `terraform.tfvars` that Windsor generates under `.windsor/` comes first. Your `<module>.tfvars` or `<module>.tfvars.json` comes after it, so Terraform applies your values last. A module that no component uses gets only your file.

In a component's directory, Windsor also writes a `backend_override.tf` and adds it to `terraform/.gitignore`, so a hand-run `terraform init` uses the context's backend. See [Lifecycle](../provisioning/state-backend.md#bootstrap) for how `bootstrap` creates that backend.

## Reference

For every variable Windsor sets per tool, run [`windsor env`](https://www.windsorcli.dev/reference/cli/commands/env) in the context you care about.

- [`windsor env`](https://www.windsorcli.dev/reference/cli/commands/env), [`windsor exec`](https://www.windsorcli.dev/reference/cli/commands/exec), [`windsor hook`](https://www.windsorcli.dev/reference/cli/commands/hook)
- [Trusted folders](trusted-folders.md)
- [Terraform components](../components/terraform.md)
