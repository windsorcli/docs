---
name: docs-validation
description: Run real windsor commands against the docs to confirm they're accurate. Designs efficient validation cycles that stack multiple assertions inside a single init→up→down lifecycle.
---

# Windsor Docs Validation

This skill exercises the locally installed `windsor` binary against
documented scenarios to confirm the docs match reality. It's for the
doc author, not for CI — windsor lifecycles are too slow for per-PR
runs.

## When to use this skill

- Adding or significantly changing a how-to page
- Updating commands or flags after a windsor release
- Spot-checking quoted output, timings, or filesystem effects in a page
- Sweeping a section before tagging a docs release

## The core idea

Real `windsor` lifecycles are slow — `windsor up` for a workstation
context takes minutes. Don't run a full `init → up → down` cycle per
assertion. Plan **one cycle** that batches every assertion you can
fit between each state transition.

```text
init local
├─ contexts/local/blueprint.yaml exists
├─ shell hook injects KUBECONFIG, TF_VAR_*
└─ `windsor context show` matches what the page says

up --wait
├─ docker network windsor-local exists
├─ dns.test resolves *.test on the host
├─ registry.test responds to `docker pull hello-world`
├─ kubectl get nodes returns N nodes Ready
├─ kubectl get pods -A all Running
├─ every assertion from workstation/ goes here
└─ ...

down
├─ docker network is gone
└─ contexts/local/ source files still present (down ≠ destroy)
```

The discipline: write the assertion list *first*, then run the cycle
once.

## Workspace

Run windsor commands at the repo root. `windsor.yaml`, `contexts/*/`,
and `.windsor/` are gitignored, so runtime artifacts never get
committed. `task sweep` removes them when you're done.

Optionally drop assertion output into `.scratch/evidence.log` for
later review:

```bash
mkdir -p .scratch
windsor --version | tee .scratch/evidence.log
windsor init local 2>&1 | tee -a .scratch/evidence.log
```

Before starting: run `windsor context show`. If it returns anything
other than `none`, you have an active context already — open a fresh
shell to avoid colliding with your existing work.

## Cycle patterns

### Full workstation lifecycle

The richest scenario — one cycle covers most of `workstation/*`.

```bash
windsor init local
ls -la contexts/local/                            # match docs anatomy
windsor env --bash | grep -E 'KUBECONFIG|TF_VAR'  # match env-injection page

windsor up --wait
docker network inspect windsor-local              # match docs network section
docker exec dns.test dig +short registry.test     # match DNS docs
kubectl get nodes -o wide                         # match cluster sizing
kubectl get pods -A                               # match expected pods
# ...stack every workstation-section assertion here...

windsor down
docker network ls | grep -q windsor-local && echo "BUG: network still up" >&2
```

### Quoted-output spot check

For pages that quote command output verbatim, capture and diff.

```bash
windsor context list > /tmp/actual.txt
# /tmp/expected.txt is the block you copied out of the page
diff /tmp/expected.txt /tmp/actual.txt
```

If the docs quote output, this is the assertion that protects them
from silent drift.

### Cross-context lifecycle

For pages about context switching or env injection across contexts.

```bash
windsor init dev
windsor init staging
windsor context use dev    ; windsor env --bash | grep KUBECONFIG
windsor context use staging; windsor env --bash | grep KUBECONFIG
# assert: KUBECONFIG points to different files
```

## Asserting

Use plain bash. Don't pull in a test framework — these aren't unit
tests, they're spot checks.

```bash
[ -f contexts/local/blueprint.yaml ] || { echo "FAIL: missing blueprint"; exit 1; }
[ "$(kubectl get nodes --no-headers | wc -l)" -ge 3 ] || { echo "FAIL: <3 nodes"; exit 1; }
windsor context show | grep -q '^local$' || { echo "FAIL: context wrong"; exit 1; }
```

Optionally pipe assertion outcomes to `.scratch/evidence.log` so a
later reader can audit what was checked without re-running:

```bash
log() { printf '%s %s\n' "$([ "$1" = pass ] && echo "✓" || echo "✗")" "$2" | tee -a .scratch/evidence.log; }

[ -f contexts/local/blueprint.yaml ] && log pass "blueprint.yaml present" || log fail "blueprint.yaml missing"
```

## Cleanup

Run `task sweep` from the repo root. It runs `windsor down`
(best-effort — no-op if no context is active) and then removes
`windsor.yaml`, `contexts/`, `.windsor/`, and `.scratch/`.

`task sweep` removes the top-level `contexts/` directory entirely.
That's safe because all docs live under `content/` — the only thing
at top-level `contexts/` is windsor runtime state.

## When validation surfaces a docs bug

The point of the skill is to catch drift between docs and reality.
When you find it:

1. Capture the actual command + output in your PR description
2. Update the docs to match what windsor actually does
3. If windsor is wrong, file an issue against `windsorcli/cli` and
   add a `// TODO(issue-link)` style note in the doc rather than
   documenting the broken behavior

## What this skill is NOT

- Not a CI replacement. Run on the doc author's machine.
- Not a substitute for integration tests in `windsorcli/cli`.
- Not a way to validate the windsor binary itself — assume the binary
  works; validate the docs.
