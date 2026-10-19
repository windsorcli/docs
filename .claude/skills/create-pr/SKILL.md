---
name: create-pr
description: Push the current branch and open its pull request with a Conventional-Commits title and an empty body. Does NOT author a PR description; the claude-pr-summary workflow writes the summary into the body when the PR opens. Use when the user asks to "open the PR", "push and PR", or after docs-review passes and the branch is ready.
disable-model-invocation: true
---

# Create or Update PR

Open a pull request for the current branch with a Conventional-Commits
title and an empty body. The `claude-pr-summary` workflow writes the
summary into the PR body, so this skill never authors a description. It
creates the PR with `--body ""` and never edits a body that already
exists.

## Apply when

- The user says "open the PR", "push the branch and PR", "make a PR",
  or similar after work is committed.
- `task lint` has passed locally and the branch has commits ahead of
  `main`.
- Skip if `git status -s` shows uncommitted changes that belong in the
  PR. Ask the user to commit or stash first.

## Inputs to gather

1. `git rev-parse --abbrev-ref HEAD`: the branch name.
2. `git log main..HEAD --oneline`: the commits the PR contains.
3. `git diff main...HEAD --stat`: the files the PR changes.
4. `gh pr view --json number 2>/dev/null`: whether a PR exists already.

## Title rules

- Conventional Commits format: `<type>(<scope>?): <description>`.
- Types: `docs`, `fix`, `chore`, `ci`, `build`, `refactor`. Most PRs
  here are `docs`.
- Scope is optional, lowercase, and a single word. Sample existing
  titles with `git log main --pretty=format:%s | head -20`.
- Description: lowercase first letter, imperative, no trailing
  punctuation.
- Length: aim for 65 characters or fewer; the hard cap is 72.

Examples that fit: `docs: rewrite the first-project tutorial in the
textbook register`, `ci: drop the attribution line from PR summaries`.

Avoid milestone prefixes such as `PR3:`. Avoid titles joined with "and"
or `+`; if the change is two things, it is probably two PRs.

## Body

Do not write a PR body. The `claude-pr-summary` workflow appends a
`> [!NOTE]` block, delimited by `<!-- claude-pr-summary -->` markers,
when the PR opens or leaves draft. A comment containing `/summary`
regenerates it. Anything written here duplicates or competes with that
block.

If a PR already exists, leave its body alone. CI owns the summary, and
a human may have added prose that must not be overwritten.

## Commands

Push first, then create the PR. Pass `--body ""` explicitly so `gh`
does not open an interactive editor.

```bash
git push -u origin "$(git rev-parse --abbrev-ref HEAD)"

PR_NUM=$(gh pr view --json number --jq '.number // empty' 2>/dev/null)
if [ -z "$PR_NUM" ]; then
  gh pr create --title "<generated title>" --body ""
  PR_NUM=$(gh pr view --json number --jq .number)
else
  echo "PR #$PR_NUM already exists; leaving its body to CI."
fi
gh pr view --json url --jq .url
```

If `gh` returns `HTTP 401: Bad credentials`, a stale `GITHUB_TOKEN`
environment variable is overriding the keychain. Prepend
`unset GITHUB_TOKEN` to the failing command and retry.

## CI status check

After the PR exists, run `gh pr checks "$PR_NUM"` once.

- If any row shows `fail`, show those rows to the user and point to the
  failing job's URL. Don't diagnose from here; the job log is the
  source of truth. The `address-pr-feedback` skill works through
  failures one at a time.
- If every row is `pending` or `queued`, print the URL and say checks
  are running. Don't wait; the user can run `gh pr checks --watch`.
- If every row is `pass`, say so.

## What NOT to do

- Don't author a PR body or edit an existing one.
- Don't push to `main`.
- Don't run `git push --force` unless the user asked for it.

Print the PR URL on its own line when done.
