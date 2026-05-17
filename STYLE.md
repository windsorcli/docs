# Windsor Docs Style Guide

This is the durable writing contract for general Windsor docs. Tooling
(markdownlint, Vale, cspell) enforces the mechanical parts. This file
covers the editorial decisions tooling can't.

## 1. Voice

- **Direct.** "Windsor reads the blueprint" beats "The blueprint is
  read by Windsor".
- **Calm.** No exclamation points outside of code samples. No
  `blazingly fast`, no `magical`, no `seamlessly`.
- **Specific.** Numbers, file paths, command names, exact behavior.
  "Fast" doesn't help; "completes in ~3 seconds on a fresh laptop" does.
- **Honest about scope.** If a feature is workstation-only, say so in
  the lead. If something needs a future release, don't promise it —
  link the tracking issue.

Banned words (Vale rejects these — list in `styles/Windsor/MarketingWords.yml`):
`seamless`, `powerful`, `simple`, `simply`, `leverages`, `robust`,
`magical`, `epic`, `cutting-edge`, `world-class`, `next-generation`,
`blazingly`, `effortless`.

Hedges to drop (`Hedging.yml`): `basically`, `just`, `really`,
`simply`, `essentially`, `obviously`, `clearly`, `of course`.

## 2. Page structure

A general page (overview, how-to, concept) follows this shape:

````markdown
---
title: Sentence-case title
description: One sentence under 160 chars. Used in OG tags and search.
---

Lead paragraph: what this page covers, who it's for, what the reader
will be able to do after. Two or three sentences.

```bash
# Minimal example up front when the page is a how-to
windsor init local
```

## Anatomy / Concepts

What the moving parts are. Use a table or mermaid diagram if the
relationships are non-obvious.

## Walkthrough

Numbered or sequential. Each step has one command and one paragraph
of explanation — not the other way around.

## Troubleshooting

Common failure modes. Each entry: symptom, cause, fix.

## Where to next

- [Related page](/docs/related)
- [Reference](/docs/reference/cli/...)
````

Reference pages (precise behavior, every flag, every field) belong in
the `cli/` or `core/` repos, not here.

## 3. Frontmatter

Required:

- `title:` — sentence case, no trailing period. Becomes the H1 and
  the browser tab.
- `description:` — one sentence under 160 characters. Becomes the
  OG description, the search snippet, and the page's entry in the
  site's `llms.txt`. Agents fetching the page in isolation depend
  on it.

Both fields are required for every page and enforced by the
frontmatter check in `docs-quality.yml`. Descriptions over 160
characters fail the check — social cards and search results
truncate at that point.

## 4. Links

- **Internal links use site paths** (`/docs/blueprints/schema`), not
  relative `.md` paths. The site flattens content from this repo,
  `cli/`, and `core/` side-by-side.
- **External links are bare URLs only inside code blocks.** Elsewhere,
  use `[label](https://...)` so the link text reads naturally.
- **Don't link to a page just because it exists.** Each link should
  pay rent — answer "what does the reader learn by following this?"

## 5. Code samples

- Every fence declares a language: `bash`, `yaml`, `terraform`,
  `mermaid`, `text` (for plain output).
- Prefer copy-pasteable. If a sample needs the reader to substitute
  values, use angle-bracket placeholders: `windsor init <context>`.
- Show output when the output is the point. Hide it when it's noise.
- Long output goes in `<details>` with a one-line `<summary>`.

## 6. Mermaid

Workstation and platform pages use mermaid to show the host/container/
cluster boundary. Existing example: `content/workstation/overview.md`.

Conventions:

- Top-level `subgraph` per boundary (Host, Docker, Cluster).
- Direction `TB` for hierarchy, `LR` for pipelines.
- Label nodes with both a name and a one-line role:
  `dns.test · 10.5.0.3<br/>CoreDNS for *.test`.
- Don't diagram things that fit in a sentence. Diagrams are for
  spatial relationships, not lists.

## 7. Pages stand alone

Agents, search results, and "Open in Claude"-style links fetch
*single pages* (or single sections), not whole sections of the docs
read top-to-bottom. Every page should make sense to a reader who
arrives via a deep link.

- **No forward references.** Don't write `as we'll see below` or
  `as discussed above` — the section the reader came from may not
  be there. Vale's `Windsor.ForwardReferences` rule flags these.
- **Repeat enough context to stand alone.** Restate which command,
  context, or layer the section is about at its start. A paragraph
  that depends on `we mentioned this above` reads broken when
  fetched in isolation.
- **Link instead of cross-referencing.** If a concept is defined
  elsewhere, link to it. Don't write `the schema (covered earlier)`;
  write `the [schema](/docs/blueprints/schema)`.
- **Headings are stable.** Don't rename `## Anatomy` to
  `## How it works` casually — every link an agent or human has
  memorized to `#anatomy` breaks. Treat heading text as part of
  the page's public API.

## 8. Plain markdown only

This repo's pages are vendored into an Astro site that supports
MDX components, but agents and tools fetching the raw markdown
get plain text. Stick to portable syntax:

- **Yes:** CommonMark, GFM tables, fenced code blocks, mermaid
  blocks, frontmatter, HTML allowed by markdownlint (`<details>`,
  `<kbd>`, `<sup>`, `<br>`, `<img>`).
- **No:** MDX components, JSX, custom Astro shortcodes, anything
  that requires the website's renderer to make sense.

If a section *only* renders correctly on the website, an agent or
a `cat` user is reading broken markup.

## 9. Terminology

`Windsor.Spelling` enforces the swaps below. Get them right the first
time and Vale stays quiet:

| Use            | Not                                |
|----------------|------------------------------------|
| Windsor CLI    | `windsorcli`, `WindsorCLI`         |
| Kubernetes     | `K8s`, `k8s`                       |
| GitHub         | `Github` (lowercase `github` is fine in URLs/paths) |
| macOS          | `MacOS`, `Mac OS`                  |
| JavaScript     | `javascript`                       |
| open-source    | `open source` (adj.); both fine as noun |
| command line   | `command-line` (noun); fine as adj.|

## 10. File naming and IA

- All pages live under `content/`. Filenames are kebab-case:
  `content/getting-started/first-project.md`.
- Each section has an `overview.md` that establishes the section's
  scope and links to its children.
- Don't duplicate a name across sections.
  `content/workstation/overview.md` and `content/blueprints/overview.md`
  is fine; two `setup.md` files isn't.

## 11. What goes elsewhere

| Topic                                       | Lives in            |
|--------------------------------------------|---------------------|
| `windsor` command reference (every flag)   | `cli/docs/reference/cli/` |
| Blueprint module reference (every input)   | `core/docs/reference/core/` |
| Architecture deep-dive (internal)          | `cli/docs/architecture/` |
| Release notes                              | release-drafter (per repo) |
| Marketing landing pages                    | `windsorcli.github.io/src/pages/` |
