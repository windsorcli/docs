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

If the diff touches behavior the docs describe — commands, flags,
file layouts, output — run [`upstream-history`](../upstream-history/SKILL.md)
first to confirm the claims still hold against cli/core HEAD.

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

Link by **where the target lives** (see
[CLAUDE.md](../../../CLAUDE.md) and
[docs-style](../docs-style/SKILL.md#link-conventions)):

- **In this repo → relative `.md` path** —
  `[lifecycle](../contexts/lifecycle.md)`. Resolves in GitHub's raw
  view and for agents fetching the raw file; the website rewrites it
  to a clean route at vendor time.
- **Off-repo (cli/core reference, anything else) → full
  `https://www.windsorcli.dev/...` URL.** Use that host *exactly* —
  the vendor step strips it to a root-relative path; a bare
  `windsorcli.dev` won't localize.
- **Bare site paths (`/blueprints/schema`) are dead links** when the
  raw `.md` is read alone. Flag every one.

Grep the diff for the two failure modes:

```bash
# bare site-absolute paths → should be a relative .md or a windsorcli.dev URL
git diff origin/main...HEAD -- '*.md' | grep -E '\]\(/[A-Za-z]'
# off-repo links — confirm the host is exactly https://www.windsorcli.dev
git diff origin/main...HEAD -- '*.md' | grep -E '\]\(https?://(www\.)?windsorcli\.dev'
```

External links must be `[label](url)`, not bare. Markdownlint MD034
catches the latter.

Cross-repo links (`/reference/cli/...`, `/reference/core/...`,
`/cli/...`) resolve only on the live site — lychee skips them via the
website-origin exclude in `lychee.toml`. If the page leans heavily on
cross-repo links, sanity-check the target paths manually against the
website's content tree.

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

### Pass 4 — Rhythm and AI-tells

Vale catches words; it does not catch *shape*. This is the read-aloud
pass — the gate that separates prose that reads as human from prose
that reads as generated. Nothing here trips CI, which is exactly why a
deliberate read is the only thing that catches it.

**Read the lead aloud first, every time.** It is written first,
carries the most weight, and is where the instinct to cram the whole
value proposition into one sentence peaks — which is the most AI-prone
sentence on the page. Don't pass-mark this whole pass without literally
reading that sentence against the list below.

Then read the rest of the changed prose and flag:

- **Uniform sentence length.** Three medium sentences in a row is the
  strongest tell. Fix: cut one to a fragment, or merge two and land on
  a short one. The calibration samples in
  [docs-style](../docs-style/SKILL.md#calibration-samples) are the
  target rhythm.
- **Consecutive sentences with the same opener** ("Windsor… Windsor…
  Windsor…", "You can… You can…"). Vary the entry.
- **Throat-clearing intros and recap outros.** "In this guide we'll
  explore…", "In summary…", a closing paragraph that restates the
  page. Cut them — the lead and the content carry it.
- **Hedging that dodges a position.** "can", "may", "often", "it's
  worth noting", "generally". State the behavior; if it's conditional,
  name the condition instead of softening the verb.
- **Reassurance tails** — "for you", "yourself", "the right/correct X",
  "so you don't have to". State what the system does: "`KUBECONFIG` is
  set for you" → "set automatically".
- **Vague list filler** — a trailing `and the rest` / `and more` /
  `and other …` / `and so on`. Name the items or bound the set.
- **Definition-thesis lead** — does the opening sentence *define the
  subject* ("X wraps Y", "X is a Y that …") or say something the reader
  can act on? Concept and `overview.md` leads are exempt.
- **Folksy idioms** — "reach for it", "surprises you", "let's". Plain
  beats chatty.
- **Docs-specific tells:** bulleting what should be one sentence;
  over-explaining a step the
  [reader baseline](../../../adrs/0001-guide-first-two-tier-pages.md)
  already knows; rule-of-three lists where the third item is padding;
  "not just X, but Y"; em-dashes in prose (convert to colon / semicolon
  / comma / parens — only `[Page — Section]` link labels and code keep
  them; in YAML frontmatter use comma/parens, never a colon).

Findings here are `should-fix` or `consider`, never `must-fix`. Quote
the sentence and propose the rewrite — don't just name the smell.

### Pass 5 — Page structure

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

For the how-to + explanation pages,
[ADR 0001](../../../adrs/0001-guide-first-two-tier-pages.md) sets the
two-tier shape: guide tier first, then a `## Under the hood` seam
(that exact text — it's part of the page API) before the mechanism. A
reader who stops at the seam should already have what they came for.
Don't require the seam on a short pure how-to.

### Pass 6 — Mechanical checks

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
- **Path and line** (`content/workstation/overview.md:42`)
- **Brief explanation** (1-2 sentences — what, why it matters, how to fix)
- **Severity**: `must-fix` (CI will reject or the page is broken),
  `should-fix` (style/voice problem worth a round-trip), or
  `consider` (subjective)

Example:

```markdown
### content/blueprints/overview.md

- **must-fix** · content/blueprints/overview.md:12 — Internal link
  uses relative path. Replace `../cli/up.md` with
  `/reference/cli/commands/up`.

- **should-fix** · content/blueprints/overview.md:34 — `seamlessly
  integrates` trips Vale's MarketingWords rule. Describe what the
  integration actually does.

- **consider** · content/blueprints/overview.md:1 — Description is
  174 chars; the OG tag truncates around 160.
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
