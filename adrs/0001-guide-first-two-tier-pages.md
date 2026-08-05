# ADR 0001 — Guide-first, two-tier pages

- **Status:** Proposed
- **Date:** 2026-06-12
- **Deciders:** Ryan
- **Applies to:** every page under `content/`

## Context

The general docs in this repo read like reference material. A typical
page opens with a conceptual definition, then moves straight into the
mechanism — flags, environment variables, internal control flow — before
the reader has any reason to care. [Environment injection](../content/contexts/environment-injection.md)
is the clearest case: it defines itself against `direnv`, then explains
`windsor env --hook` and `WINDSOR_MANAGED_ENV` before the reader knows
what problem any of that solves for them.

That shape suits an operator who already knows Windsor and wants to look
something up. It does not suit the person we are actually writing for: a
power user who lives in a terminal, runs `sudo` without thinking, and can
follow a `kubectl` command — but who has read about containers rather
than built one, and has likely never written Terraform. They need to
know what a page lets them *do* before they need to know how it works.

The detail still matters. We do not want to delete the mechanism — a lot
of it is correct and hard-won. We want to stage it: lead with the guide,
keep the internals, and put a clear seam between the two so each reader
stops where their interest does.

Three constraints from this repo shape the decision:

- Pages must stand alone. Agents and search fetch single pages and single
  sections, so the guide half and the under-the-hood half each have to
  make sense on their own.
- Plain markdown only — no MDX, no Astro components. Anything visual has
  to survive being read as raw `.md`.
- Headings are part of a page's public API. A new standard heading is a
  commitment we keep across the tree.

## Decision

### 1. Reader baseline

Write for a "power user who can `sudo`." Concretely, assume the reader:

- is fluent in a shell — editing `~/.zshrc`, running `sudo`, reading
  command output. Do not explain what a shell hook or an environment
  variable is.
- can run a `kubectl` command and read its output. Assume `kubectl`
  exists; still explain Flux, Kustomize, and Talos specifics.
- understands a container conceptually but has never built one. Do not
  define "container," but do explain image builds, runtimes, and
  anything Windsor does to a container that a reader would not predict.
- has probably not written Terraform. Explain state, modules, and the
  generated module shims when a page depends on them.

This baseline is a calibration aid, not an audience label to repeat in
prose. It tells us where to stop explaining, not who to address.

### 2. Page type — classify before you shape

Before choosing a page's shape, name what the page is *for*. Diátaxis
(Daniele Procida) sorts documentation into four types by the reader need
each serves:

- **Tutorial** — learning by guided doing. The reader follows along and
  builds footing. (`getting-started/`)
- **How-to** — accomplishing a task whose shape the reader already
  understands. Focused on the outcome, not on teaching. (`deployment/`,
  most of `workstation/`)
- **Reference** — dry facts to look up, no interpretation. **Out of scope
  for this repo** by charter — it lives in `windsorcli/cli` and
  `windsorcli/core`.
- **Explanation** — the *why* and the bigger picture. (`overview.md`
  pages, concept pages)

With reference handed off, this repo carries three types. Each page should
serve **one** primary need well rather than all of them at once — the
failure mode across the current tree, where a how-to opens with a concept
lecture before the reader has a reason to care.

Diátaxis's own guidance is to apply this **in place, page by page**. It
warns against pre-building empty `tutorial/how-to/reference/explanation`
folders ("Don't do that. It's horrible.") and holds that the right
structure emerges as individual pages improve. So we classify each page,
fix it on its own terms, and let the information architecture settle — we
do not reshuffle the tree up front.

| Section / pages | Primary type | Shape |
|---|---|---|
| `getting-started/first-project` | Tutorial | Task-first; seam optional |
| `*/overview` (contexts, blueprints, workstation) | Explanation | Concept-first |
| `contexts/{lifecycle,environment-injection,trusted-folders}` | How-to + Explanation | Two-tier |
| `blueprints/{templates,facets,schema,terraform,kustomize,sharing,testing,explain}` | How-to + Explanation; some near-reference | Two-tier; move pure reference to `core` |
| `deployment/{aws,azure,metal,secrets-management,securing-secrets}` | How-to | Task-first; seam optional |
| `workstation/{colima-docker,colima-incus,docker-desktop,build-id}` | How-to | Task-first |
| `troubleshooting/overview` | How-to (problem-solving) | Symptom → cause → fix |

Classifying also surfaces **misfiled pages**: any blueprint page that is
really an input-by-input reference table belongs in `windsorcli/core`, not
here. Flag those during the pilot instead of restyling them in place.

### 3. Two-tier page shape (task first, explanation under the hood)

This is the shape for the **how-to + explanation** pages — the bulk of
this repo. The page resolves to one URL with two tiers: a guide tier
first, an under-the-hood tier after a fixed seam heading.

```text
---
title: ...
description: ...
---

Lead — what this does for you, in one or two sentences. No mechanism.

[ optional: media placeholder showing the thing working ]

## <Task or outcome heading>     <- guide tier
Narrative + the commands a reader runs, in order. Scenario-driven.

## <When / where it applies>     <- guide tier, still practical
The conditions, modes, and gotchas a reader hits in normal use.

## Under the hood                <- the seam. Everything below is optional reading.
The mechanism: flags, env vars, control flow, file layout.

## Reference                     <- links out to cli/core reference + related pages
```

Rules for the shape:

- **`## Under the hood` is the standard seam.** Use that exact text. It
  is now part of the page API, like `## Anatomy` and `## Reference`. A
  reader who stops at the seam should already have what they came for.
- **The guide tier carries the commands.** Do not hold the
  copy-pasteable path hostage to the mechanism. A reader should be able
  to act from the guide tier alone.
- **The under-the-hood tier is optional reading, not an appendix.** It is
  still accurate, still maintained, still linked. It is staged later
  because most readers do not need it on the first pass — not because it
  matters less.
- **Short pages may skip the seam.** If a page has no real internals to
  stage (a pure how-to), it stays single-tier. The seam is a tool, not a
  quota.
- **Explanation-first pages invert the lead.** A concept or `overview.md`
  page opens with the *why*, not a task, because its primary type
  (section 2) is explanation. It uses `## Under the hood` only when it has
  mechanism worth staging; otherwise it stays single-tier. Match the lead
  to the page's primary type.
- **Pages still stand alone.** The under-the-hood tier restates which
  command or context it concerns at its start, so a reader who deep-links
  to it is not stranded.

This extends the page-structure contract in [STYLE.md](../STYLE.md)
section 2 rather than replacing it: the existing
`Anatomy → Walkthrough → Troubleshooting → Where to next` skeleton maps
onto the guide tier, with `Under the hood` inserted before the outbound
links.

### 4. Media placeholders

Pages get visible placeholder images where a recording, screenshot, or
animation belongs, so the gaps are obvious in review and easy to fill
later.

- A single reusable asset lives at
  [content/assets/media-placeholder.svg](../content/assets/media-placeholder.svg).
  It renders as a neutral 16:9 card on GitHub and on the site, and it
  resolves for the link checker because it is a real file.
- Reference it with a standard markdown image whose **alt text is the
  spec** for the eventual recording — descriptive enough that whoever
  records it knows what to capture:

  ```markdown
  ![windsor up --wait bringing the local stack to ready](../assets/media-placeholder.svg)
  ```

- All `content/` sections sit one directory under `content/`, so the
  relative path is always `../assets/media-placeholder.svg`.
- To find every outstanding placeholder, grep for `media-placeholder.svg`.
  Swapping in the real asset is a one-line edit to the image target.

The alternative of an HTML-comment marker was considered and set aside:
an invisible marker does not show up in a rendered review pass, and the
point of these is to make the missing media visible.

### 5. Voice

No change to the [STYLE.md](../STYLE.md) voice contract — direct, calm,
specific, banned marketing words. The guide tier leans harder on second
person ("you run `windsor up`") and on the concrete scenario, which the
existing voice rules already allow.

## Prior art and references

The page model above applies three established sources rather than
inventing one:

- **[Diátaxis](https://diataxis.fr/)** (Daniele Procida) — the four-type
  model and the "improve in place, don't pre-build empty structures"
  workflow. The page-type classification in section 2 is Diátaxis applied
  directly; the `## Under the hood` seam is the line Diátaxis draws
  between *how-to* and *explanation*, drawn within a page rather than
  across pages.
- **[Progressive disclosure](https://www.nngroup.com/videos/progressive-disclosure/)**
  (Jakob Nielsen, NN/g, 1995) — lead with the core layer, defer the
  advanced layer on demand. NN/g's finding that **more than two
  disclosure levels hurts usability** is why the model stops at two tiers:
  a guide layer and one optional layer under the seam, never a third.

**Where we diverge from strict Diátaxis.** Diátaxis would put a how-to and
its explanation on *separate pages*. We co-locate them behind the seam
because this repo's pages must stand alone at a single URL — agents and
deep links fetch one page, not a section read top to bottom. Progressive
disclosure makes that co-location sound: one page, one optional second
layer. We adopt Diátaxis's *classification* and its *in-place workflow*,
and use the seam to honor its type boundary without fragmenting a page
that a reader arrives at cold.

## Scope and rollout

Applies to all of `content/`. Roll out in phases so the pattern can
settle before it is stamped across two dozen pages:

0. **Classify.** Tag each page with its primary Diátaxis type (the table
   in section 2 is the first pass). This costs little and tells each later
   phase which shape applies — and flags any page that is misfiled
   reference belonging in `core`.
1. **Pilot — `contexts/`.** Convert the four context pages, starting with
   [environment injection](../content/contexts/environment-injection.md).
   Use them as the worked reference for the shape.
2. **Narrative-heavy sections.** `getting-started/`, `blueprints/`, and
   the top-level [overview](../content/overview.md).
3. **Remaining sections.** `deployment/`, `workstation/`,
   `troubleshooting/`.

Each phase is its own PR, validated with the `docs-review` and
`docs-validation` skills before it merges.

## Consequences

**Good**

- Readers get to action faster; the mechanism is there for those who want
  it, gated behind one predictable heading.
- The reader baseline gives a concrete test for "are we over-explaining?"
- Visible media gaps make the docs' incompleteness honest instead of
  hidden, and give a clean hand-off to whoever records the demos.
- Diátaxis classification gives each page a single job, and the act of
  classifying surfaces pages that are misfiled reference — a structural
  fix the restyle would otherwise paper over.

**Costs**

- `## Under the hood` becomes a tree-wide heading commitment. Renaming it
  later breaks deep links, same as any other heading.
- Two tiers per page is more editorial work than a flat rewrite, and the
  seam placement is a judgment call that will vary by page.
- Placeholder images are visible debt. A page can ship looking finished
  while its demos are unrecorded; the grep target is the backstop.

## Open questions

- **Does the website vendor step carry `content/assets/`?** The relative
  link resolves on GitHub and for the link checker today. Whether
  `windsorcli.github.io`'s `vendor-docs.mjs` copies non-markdown assets
  into its content collection needs confirming before the first page with
  a placeholder is tagged for release. Track against the website repo.
- **One generic placeholder or typed variants?** Starting with one. If
  review shows readers cannot tell an intended screenshot from an
  intended screencast, add typed cards (`media-placeholder-video.svg`,
  `media-placeholder-shot.svg`) and keep the alt-text-as-spec rule.

## Worked example

The intended transform for [environment injection](../content/contexts/environment-injection.md):

```text
BEFORE (reference-first)
  Lead: defines itself against direnv
  ## How it works      -> windsor env --hook, WINDSOR_MANAGED_ENV
  ## Project / global  -> mode mechanics
  ## Sample            -> raw env dump
  ## Reference

AFTER (guide-first)
  Lead: "Switch contexts and your KUBECONFIG, cloud profile, and
        Talos config follow — without you exporting anything."
  [ media placeholder: a context switch updating the prompt env ]
  ## Set it up once         -> windsor hook, trust the folder, done
  ## What changes when      -> project vs global, trusted folders
     you switch                (still practical, no internals)
  ## Under the hood         -> windsor env --hook, the eval loop,
                               WINDSOR_MANAGED_ENV, suppression matrix
  ## Reference
```
