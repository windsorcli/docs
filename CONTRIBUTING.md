# Contributing to Windsor Docs

This repo holds Windsor's general documentation — concepts, how-tos,
and platform overviews. Reference docs (every flag, every field) live
in [`windsorcli/cli`](https://github.com/windsorcli/cli) and
[`windsorcli/core`](https://github.com/windsorcli/core).

Read [STYLE.md](STYLE.md) before writing. It covers voice, page
structure, and terminology.

## Local checks

The Docs Quality workflow runs these on every PR. Run them locally
first to skip the CI round-trip.

### One-shot install

```bash
# Linters
npm install -g markdownlint-cli2@0.14.0 cspell@8.14.4 alex@11.0.1

# Vale (macOS)
brew install vale lychee

# Vale (Linux)
curl -fsSL https://github.com/errata-ai/vale/releases/latest/download/vale_$(uname -s)_$(uname -m).tar.gz \
  | tar -xz -C /usr/local/bin vale
```

The first `vale` run downloads the Microsoft style pack listed in
`.vale.ini` (writes to `styles/Microsoft/`). That directory is
gitignored.

```bash
vale sync
```

### Run a check

```bash
markdownlint-cli2 "**/*.md" "#node_modules"
vale .
cspell --no-progress "**/*.md"
lychee --config lychee.toml --no-progress '**/*.md'
alex --quiet '**/*.md'
```

### Frontmatter check

The workflow rejects any page missing `title:` in YAML frontmatter.
Mirror it locally:

```bash
find . -name '*.md' -not -path './node_modules/*' \
  ! -name 'README.md' ! -name 'LICENSE*' \
  -exec sh -c '
    head -1 "$1" | grep -qx "---" || { echo "no frontmatter: $1"; exit 1; }
    awk "/^---$/{c++; next} c==1{print} c==2{exit}" "$1" \
      | grep -Eq "^title:[[:space:]]*\S" || { echo "no title: $1"; exit 1; }
  ' _ {} \;
```

## Previewing against the website

This repo's markdown is vendored into
[windsorcli.github.io](https://github.com/windsorcli/windsorcli.github.io)
at build time. To render a draft page locally:

```bash
# In a sibling clone of windsorcli.github.io
cd ../windsorcli.github.io
npm install
WINDSOR_DOCS_ROOT=$(realpath ../docs) npm run dev
```

The Astro dev server symlinks straight into this repo, so edits show
up immediately. See
[the website's vendor-docs script](https://github.com/windsorcli/windsorcli.github.io/blob/main/scripts/vendor-docs.mjs)
for what the `WINDSOR_DOCS_ROOT` (and `WINDSOR_CLI_DOCS_ROOT`,
`WINDSOR_CORE_DOCS_ROOT`) variables do.

## Opening a PR

Apply at least one of these labels — the changelog can't categorize
the PR without one and CI rejects unlabeled PRs:

`feature` · `enhancement` · `fix` · `chore` · `dependencies` ·
`content` · `restructure`

If the change is substantial, link the
[windsorcli.github.io](https://github.com/windsorcli/windsorcli.github.io)
PR or include a screenshot of the rendered page.

## Working with Claude Code

The [CLAUDE.md](CLAUDE.md) at the repo root sets the context. Skills
in [.agent/skills/](.agent/skills/) cover the editorial and validation
workflows:

- `docs-style` — voice, frontmatter, link conventions
- `docs-review` — pre-PR pass over a page or diff
- `docs-validation` — run real `windsor` commands against documented
  scenarios. Cleans up with `task sweep`.
- `upstream-history` — investigate `windsorcli/cli` and
  `windsorcli/core` history before writing or revising behavior claims

Invoke them with `/<skill-name>` in Claude Code.
