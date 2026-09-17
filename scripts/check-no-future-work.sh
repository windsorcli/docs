#!/usr/bin/env bash
#
# Fail if a documentation page uses future-work framing: a "not covered
# yet"-style heading, or roadmap/TODO phrasing about the page's own
# subject. Docs describe what's true right now, not what's planned.
#
# A "page" is a markdown file under content/ — same scope and definition
# as check-frontmatter.sh. Repo-meta files (README.md, CLAUDE.md, skill
# files) are not pages and are skipped.
#
# Called from .github/workflows/docs-quality.yml and Taskfile.yaml so the
# local and CI checks use the exact same logic. Returns 0 on pass, 1 on
# any failure.

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

# Heading-level banners that announce unfinished work by name. A heading is
# an unambiguous signal — "here is what this page doesn't do yet" — unlike
# inline "not yet", which also shows up describing real runtime state (an
# IP not yet assigned mid-apply) that has nothing to do with unfinished
# documentation.
HEADING_PATTERN='^#+ *(Not (Covered|Built|Implemented|Supported|Decided) Yet|Coming Soon|Future Work|Roadmap|TODO|Todo)\b'

# Inline phrases proven, in practice, to be future-work framing rather than
# a description of current state. Deliberately narrow — see HEADING_PATTERN
# comment above for why a bare "not yet" isn't on this list.
PHRASE_PATTERN='planned follow-up|on the roadmap|not yet a component|target service set|is a real follow-up, not decided|coming soon|not yet built|not covered here yet|not covered yet'

while IFS= read -r -d '' f; do
  is_page "$f" || continue

  hits="$(grep -nEi "$HEADING_PATTERN" "$f" || true)"
  if [ -n "$hits" ]; then
    emit "$f" "has a future-work heading — docs describe the current state, cut the section or fold any current-state fact into prose"
    printf '%s\n' "$hits" >&2
    failed=1
  fi

  hits="$(grep -nEi "$PHRASE_PATTERN" "$f" || true)"
  if [ -n "$hits" ]; then
    emit "$f" "uses future-work phrasing — docs describe the current state, not planned work"
    printf '%s\n' "$hits" >&2
    failed=1
  fi
done < <(find . -name '*.md' -not -path './node_modules/*' -not -path './styles/*' -print0)

exit "$failed"
