#!/usr/bin/env bash
#
# Enforce required YAML frontmatter on every documentation page.
#
# A "page" is a markdown file under content/, vendored into
# windsorcli.github.io as a content page. Every page must declare:
#   - title:        non-empty, becomes the H1 and browser tab
#   - description:  non-empty, ≤160 chars, used for OG tags, search
#                   snippets, and the site's llms.txt index
#
# Repo-meta files (README.md, CLAUDE.md, STYLE.md, CONTRIBUTING.md,
# .github/, .agent/ skill files) are not pages and use different
# conventions, so they're skipped.
#
# Called from .github/workflows/docs-quality.yml and Taskfile.yaml so
# the local and CI checks use the exact same logic. Returns 0 on pass,
# 1 on any failure.

set -euo pipefail

failed=0

emit() {
  if [ "${GITHUB_ACTIONS:-}" = "true" ]; then
    printf '::error file=%s::%s\n' "$1" "$2"
  else
    printf '%s: %s\n' "$1" "$2" >&2
  fi
}

is_page() {
  case "$1" in
    ./content/*.md) return 0 ;;
    *)              return 1 ;;
  esac
}

while IFS= read -r -d '' f; do
  is_page "$f" || continue

  first_line=$(head -1 "$f")
  if [ "$first_line" != "---" ]; then
    emit "$f" "missing YAML frontmatter (first line must be '---')"
    failed=1
    continue
  fi

  fm=$(awk '/^---$/{c++; next} c==1{print} c==2{exit}' "$f")

  if ! printf '%s\n' "$fm" | grep -Eq '^title:[[:space:]]*\S'; then
    emit "$f" "missing non-empty title: in frontmatter"
    failed=1
  fi

  desc=$(printf '%s\n' "$fm" | sed -n 's/^description:[[:space:]]*//p' | sed "s/^[\"']//;s/[\"']$//")
  if [ -z "$desc" ]; then
    emit "$f" "missing non-empty description: in frontmatter"
    failed=1
  elif [ "${#desc}" -gt 160 ]; then
    emit "$f" "description is ${#desc} chars (max 160) — OG/search snippets truncate"
    failed=1
  fi
done < <(find . -name '*.md' -not -path './node_modules/*' -not -path './styles/*' -print0)

exit "$failed"
