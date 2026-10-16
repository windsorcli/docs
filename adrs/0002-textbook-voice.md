# ADR 0002 — Textbook voice and chapter-order sections

- **Status:** Proposed
- **Date:** 2026-10-16
- **Deciders:** Ryan
- **Amends:** [ADR 0001](0001-guide-first-two-tier-pages.md), sections 3 and 5
- **Applies to:** every page under `content/`

## Context

ADR 0001 fixed the order of a page: the task first, the mechanism after a
`## Under the hood` seam. It did not change how the prose itself reads, and
the prose still reads like documentation. Pages open with a definition, list
the parts in a table, and close each paragraph with "See X." A reader comes
away knowing which files exist but not how they fit together or why they
were designed that way.

The blueprints overview made the problem concrete. Its first draft explained
how facet entries merge before it had said what a facet is. A second pass
that fixed the word choice still read as generated, because the structure
underneath was a list of fragments joined by links.

Technical books solve this differently. An O'Reilly title or a good
textbook introduces one idea at a time, motivates it with the problem it
solves, shows a worked example, and only then states the general rule. Each
chapter builds on the one before it. That is the register this repo wants.

Two constraints from ADR 0001 still hold. Agents and search results fetch
single pages, so a page cannot depend on the reader having arrived from the
previous one. And pages are plain markdown, so anything visual has to read
correctly as raw `.md`.

## Decision

### 1. Write explanations the way a textbook does

A concept section moves through four steps, in this order:

1. **The problem.** What the reader cannot do, or would do badly, without
   this concept. One or two sentences, grounded in a real scenario.
2. **An example.** The smallest real listing or command that shows the
   concept working. Use real values from `core` or a validated run, never
   `foo` and `bar`.
3. **The mechanism.** Walk through the example and say what Windsor does
   with each part that matters.
4. **The general rule.** State what holds beyond this one example, then
   link to the page that covers the rest.

Explanation lives in paragraphs. A paragraph opens with its topic sentence
and builds on the paragraph before it instead of restating it. Tables and
lists hold lookup material only: a set of four or more parallel items the
reader scans, such as the modules per platform. A table never stands in for
an explanation of how its rows relate.

### 2. Introduce terms before using them

A term is defined at its first use on a page, in *italics*, in a sentence
that says what it is in plain words. After that the page uses the term
without redefining it. If a page uses a term that its section overview
defines, the first use is a link to that definition instead of a second
definition.

### 3. Sections read in order, like chapters

Each section has an `overview.md` that works as a chapter introduction. It
names the problem the section addresses, introduces the section's core
terms in the order the child pages build on them, and links to each child.

Child pages are ordered in the site navigation and may assume the terms
their section overview defines. They still stand alone for a reader who
arrives cold, through links rather than repetition: the first use of an
assumed term links back to where it is defined. Phrases that point back to
earlier reading, such as "as we saw," stay banned
(`Windsor.ForwardReferences`), because the reader may not have seen it.

A section may carry one *running example* across its pages, such as an
`aws` context named `production`. Introduce the example in the overview and
reuse the same names and values on every page that refers to it.

### 4. Code listings

Introduce each listing with a complete sentence that names what it shows:
"`platform-aws.yaml` declares two Terraform components and one Flux system."
The sentence must make sense on its own, so do not end it with a bare colon
or write "the following." After the listing, explain the lines that matter
by naming the key or command, for example "The top-level `when:`". Do not
point at a listing by position ("the code above"). A listing trimmed from a
real file says so in its introduction and links to the full file.

O'Reilly books number their examples ("Example 3-2 shows"). These pages do
not, because a number only means something inside a book read in order.
Name the file or command instead.

### 5. Voice

The reader is "you." There is no authorial "we." In explanation the system
is the subject: "Windsor merges entries that share a name." In a walkthrough
the reader is: "You run `windsor up`." Everything in the
[STYLE.md](../STYLE.md) voice contract still applies: direct, calm,
specific, no marketing words, no em-dashes in prose.

### 6. Callouts

Asides that would interrupt the main line of explanation go in a GitHub
alert:

```markdown
> [!NOTE]
> `backend/s3` only appears when Windsor manages the state bucket.
```

Use the five GitHub types for their GitHub meanings:

| Type        | Use for                                                    |
| ----------- | ---------------------------------------------------------- |
| `NOTE`      | Context the reader can skip without going wrong            |
| `TIP`       | A faster or easier way to do what the text just described  |
| `IMPORTANT` | A requirement the reader must meet for the step to work    |
| `WARNING`   | An action that destroys data or breaks a running cluster   |
| `CAUTION`   | An action that cannot be undone                            |

A callout holds one point. Never stack two callouts back to back. If a page
needs more than two or three, the asides belong in the main text.

GitHub renders alerts natively, and in raw markdown they read as an
ordinary blockquote. The website renders them through
`src/lib/remark-github-alerts.mjs` in `windsorcli.github.io`. The marker
must sit alone on the first line of the blockquote, as GitHub requires.

### What changes in ADR 0001

- **Section 3 (page shape).** The two-tier shape stays for how-to and
  explanation pages, and `## Under the hood` stays the seam heading. Inside
  each tier, the prose follows sections 1 to 4 here. The STYLE.md skeleton
  (`Anatomy`, `Walkthrough`, `Troubleshooting`) becomes a set of available
  headings, not a template every page fills.
- **Section 5 (voice).** Replaced by section 5 here.

The page-type classification (ADR 0001 section 2), the reader baseline
(section 1), and the media placeholders (section 4) are unchanged. Existing
headings stay as they are, since renaming them breaks deep links.

## Prior art and references

- **[O'Reilly's default stylesheet](https://svn.red-bean.com/repos/producingoss/trunk/oreilly/O'Reilly%20Default%20Stylesheet%20and%20Word%20List.htm)**,
  which takes the *Chicago Manual of Style* as its general reference. This
  ADR adopts three of its rules: italics for the first instance of a
  technical term, code introduced by a specific reference in the text
  rather than "in the following" or a colon, and asides tagged as notes
  instead of footnotes. It departs on two. O'Reilly numbers examples, which
  only works in a book read in order, and capitalizes its top two
  heading levels in title case, while this repo keeps sentence case because
  heading text is part of each page's URL anchors.
- **Textbook chapter structure**: problem, worked example, general rule, in
  that order, with each chapter assuming the ones before it.
- **[GitHub alerts](https://docs.github.com/en/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/basic-writing-and-formatting-syntax#alerts)**:
  the callout syntax, chosen because it renders on GitHub and degrades to a
  blockquote everywhere else.

## Scope and rollout

1. **Style contract.** Update [STYLE.md](../STYLE.md), the `docs-style` and
   `docs-review` skills, and `CLAUDE.md` to match this ADR. Ship the
   website's alert plugin before the first page that uses a callout.
2. **Pilot: `blueprints/`.** Its overview is already being rewritten. Use it
   as the chapter-introduction model, then carry its running example through
   facets, schema, and expressions.
3. **Remaining sections**, one PR per section, each checked with
   `docs-review` and, for any how-to it touches, `docs-validation`.

## Consequences

**Good**

- Concepts arrive in an order a reader can follow, and each one is
  motivated before it is explained.
- A running example per section ties pages together without breaking
  single-page reads.
- Callouts take asides out of the main sentence, which shortens it.

**Costs**

- Textbook prose is longer than fragment-style docs and takes more
  editorial time per page.
- Chapter order makes the site navigation part of the content. Reordering
  pages in a section means checking that each page's assumed terms still
  come from a page before it.
- Callout rendering on the site depends on a plugin in another repo. Until
  it ships, the site shows each alert as a plain blockquote with the `[!NOTE]` marker
  visible.
