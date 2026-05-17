---
name: upstream-history
description: Investigate the windsorcli/cli and windsorcli/core repos before writing or revising docs about an evolving feature. Tells you what the code actually does, when it changed, and what's in flight.
---

# Upstream History

The docs in this repo describe the cli and core codebases. Those
codebases move. This skill is the workflow for grounding doc work in
what those codebases actually do — not what they did six months ago
when a page was last touched.

## When to use this skill

- Writing a new page about a feature, command, or subsystem
- Revising claims about behavior on an existing page
- Reviewing a section after a cli or core release
- Investigating why your `docs-validation` cycle saw something the
  page doesn't mention

Skip this skill for: typo fixes, restructures, voice/style passes.

## Layout

The cli and core repos live as siblings of this one:

```text
windsorcli/
├── cli/    # the CLI binary, command implementations, package code
├── core/   # the default blueprint (kustomize add-ons, terraform modules)
└── docs/   # you are here
```

If the siblings aren't present, clone them — most investigation
commands below need a local checkout. The windsorcli.github.io
website also assumes this layout for the local preview flow.

## The half-hour playbook

When a page needs grounding, run these four passes. Each is
self-contained — drop the ones that don't apply.

### 1. Locate the feature in the code

```bash
# Replace <term> with the feature name (blueprint, context, env, etc.)
grep -rl --include='*.go' '<term>' ../cli/pkg | head
find ../core -type d -name '<term>'
```

Note the canonical path. You'll reuse it for the rest of the passes.

### 2. Read recent commits

```bash
git -C ../cli log --oneline --since='6 months ago' -- pkg/<feature>/
git -C ../core log --oneline --since='6 months ago' -- kustomize/<addon>/
```

Look for:

- **Birth commits** — when the feature first appeared. Useful for
  dating "as of vN.N" claims.
- **Refactors** — large diffs that may have changed the API or
  output. Likely sources of doc drift.
- **Deprecation/removal commits** — pages may describe code that no
  longer exists.

### 3. Pull design intent from merged PRs

```bash
gh pr list --repo windsorcli/cli --state merged --search '<feature> in:title,body' --limit 20
gh pr view <number> --repo windsorcli/cli
```

PR descriptions carry the *why* that commit messages often skip.
They're the best source for design intent and the public contract.

### 4. Check what's in flight

```bash
gh pr list --repo windsorcli/cli --state open  --search '<feature>'
gh issue list --repo windsorcli/cli --state open --search '<feature>'
```

If something is mid-rework, either:

- Wait for it to land before documenting
- Document only the stable parts and link the open PR
- Note that the section reflects a specific version

Don't write speculative docs against unmerged code.

## Integrating findings

The investigation produces three kinds of doc work:

**Match reality.** The most common case — the page describes an
older shape of the feature. Update the prose and code samples to
match HEAD. Cite the PR that changed things in your own PR
description so reviewers can sanity-check.

**Mark in-flux content.** If a feature is mid-rework, narrow the
page's scope to what's stable. Use specific version references
(`as of vN.N.N`) rather than vague phrasing. Don't pretend the
in-flight work doesn't exist.

**Push back upstream.** If the code is wrong (behavior doesn't
match a reasonable user expectation, or contradicts what other docs
imply), file an issue against `windsorcli/cli` or `windsorcli/core`
rather than documenting the broken behavior. Link the issue from
the doc PR.

## What this skill is NOT

- Not a substitute for reading the code. Commit history tells you
  *that* something changed; the code tells you *what it does*.
- Not a gate. Many doc PRs (style fixes, restructures, typos) don't
  touch evolving behavior and don't need this.
- Not a guarantee. Even after thorough investigation, the
  `docs-validation` skill running real commands is the only thing
  that proves the docs match reality.
