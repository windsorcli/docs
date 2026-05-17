---
name: docs-review
description: Pre-PR pass over a docs page or diff. Checks frontmatter, links, terminology, voice, and runs the same linters CI runs. Use before opening a PR.
---

# Windsor Docs Review

Pre-PR review skill for the Windsor docs repo. Pairs with
[`docs-style`](../docs-style/SKILL.md) — that one is for *writing*,
this one is for *checking*.

## When to use this skill

- Just before opening a PR
- After a substantial rewrite of a page
- When asked to review someone else's draft

## What to review

Review the **diff**, not the whole page, unless the page is new.
Reach for `git diff origin/main...HEAD -- '*.md'`.

For each changed page, run these passes. Each has a clear pass /
fail signal — don't editorialize on things outside the pass.

### Pass 1 — Frontmatter

Every changed page that's a documentation page (not README, not
LICENSE) must have:

```yaml
---
title: ...        # non-empty, sentence-case, no trailing period
description: ... # non-empty, one sentence, under 160 chars
---
```

CI rejects pages without `title:` via the frontmatter check in
[docs-quality.yml](../../../.github/workflows/docs-quality.yml).

### Pass 2 — Links

Internal links must use site paths (`/docs/...`), not relative
`.md` paths. Grep the diff:

```bash
git diff origin/main...HEAD -- '*.md' | grep -E '\]\(\.\.?/[^)]+\.md\)'
```

External links must be `[label](url)`, not bare. Markdownlint MD034
catches the latter.

Cross-repo links (`/docs/reference/cli/...`, `/docs/reference/core/...`)
resolve only on the live site — lychee skips them per `lychee.toml`.
If the page leans heavily on cross-repo links, sanity-check the
target paths manually against the website's content tree.

### Pass 3 — Voice and terminology

Run Vale locally:

```bash
vale .
```

Pay attention to:

- `Windsor.MarketingWords` (warning) — drop the word, don't argue
- `Windsor.Spelling` (error) — terminology must match the table
- `Windsor.FutureTense` (suggestion) — "will support" → link an issue
- `Windsor.Hedging` (suggestion) — drop "basically", "just", etc.

Don't fight the Microsoft rules that fire as `suggestion`. Fix
`error` and `warning` levels; ignore `suggestion` unless the prose
genuinely reads better with the change.

### Pass 4 — Page structure

Skim each changed page against the canonical shape:

1. Frontmatter
2. Lead (2-3 sentences)
3. Minimal example (for how-to pages)
4. Anatomy / concepts
5. Walkthrough
6. Troubleshooting
7. Where to next

A page may genuinely not need every section. But if a page is missing
a *lead*, that's always a problem.

### Pass 5 — Mechanical checks

Run the linters the CI workflow runs:

```bash
markdownlint-cli2 "**/*.md" "#node_modules"
cspell --no-progress "**/*.md"
lychee --config lychee.toml --no-progress '**/*.md'
alex --quiet '**/*.md'
```

Don't open the PR with red on any of these.

## Output format

Report findings as a checklist. Group by file. For each finding give:

- **One-line title** (what's wrong)
- **Path and line** (`workstation/overview.md:42`)
- **Brief explanation** (1-2 sentences — what, why it matters, how to fix)
- **Severity**: `must-fix` (CI will reject or the page is broken),
  `should-fix` (style/voice problem worth a round-trip), or
  `consider` (subjective)

Example:

```markdown
### blueprints/overview.md

- **must-fix** · blueprints/overview.md:12 — Internal link uses
  relative path. Replace `../cli/up.md` with `/docs/reference/cli/commands/up`.

- **should-fix** · blueprints/overview.md:34 — "seamlessly integrates"
  trips Vale's MarketingWords rule. Describe what the integration
  actually does.

- **consider** · blueprints/overview.md:1 — Description is 174 chars;
  the OG tag truncates around 160.
```

End with one sentence on overall readiness: "Ready to merge after
must-fix items" or "Needs another pass before review."

## What not to do

- Don't review unchanged content. The reader will too — don't waste
  the round-trip.
- Don't editorialize on style choices the writer made deliberately.
  If it doesn't violate STYLE.md, leave it.
- Don't suggest splits or restructures during pre-PR review. Open an
  issue for that conversation instead.
