#!/usr/bin/env bash
#
# Open one chapter's pages in VS Code, with the docs site's rendering of
# the active page in a pane beside the editor. The pane comes from the
# extension in tools/vscode-preview; the site re-vendors and reloads on
# every save.
#
#   scripts/author.sh              # the contexts chapter
#   scripts/author.sh workstation  # content/workstation/
#
# The site checkout defaults to windsorcli.github.io beside this repo's
# main checkout (found through the git common dir, so it resolves the
# same way from any worktree). Set WINDSOR_SITE_PATH to use another one.
#
# The dev server listens on port 4321. When a server there already
# renders this checkout, the script reuses it. When it renders another
# checkout and this script started it, the script stops it and starts a
# new one. A server this script did not start is never stopped. The
# script records the servers it starts in <git common dir>/windsor-author/,
# which all worktrees share, and logs the server's output there.

set -euo pipefail

chapter="${1:-contexts}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
common="$(git -C "$root" rev-parse --path-format=absolute --git-common-dir)"
site="${WINDSOR_SITE_PATH:-$(cd "$common/../.." && pwd)/windsorcli.github.io}"
state="$common/windsor-author"
pidfile="$state/dev-server.pid"
log="$state/dev-server.log"
port=4321

err() { echo "error: $*" >&2; exit 1; }

[ -d "$root/content/$chapter" ] || err "no chapter at content/$chapter"
[ -f "$site/package.json" ] || err "no site checkout at $site (set WINDSOR_SITE_PATH)"
[ -d "$site/node_modules" ] || err "the site has no node_modules; run 'npm install' in $site"

code_bin="$(command -v code || true)"
[ -n "$code_bin" ] || code_bin="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
[ -x "$code_bin" ] || err "VS Code's code command was not found"

pages=("$root/content/$chapter"/*.md)
[ -f "${pages[0]}" ] || err "content/$chapter has no pages"
page="overview"
[ -f "$root/content/$chapter/overview.md" ] || page="$(basename "${pages[0]}" .md)"
url="http://localhost:$port/$chapter/$page"

# Install the preview extension when it is missing or older than the repo's.
want="$(node -p 'require(process.argv[1]).version' "$root/tools/vscode-preview/package.json")"
have="$("$code_bin" --list-extensions --show-versions | sed -n 's/^local\.windsor-docs-preview@//p')"
if [ -z "$have" ] || { [ "$have" != "$want" ] && [ "$(printf '%s\n%s\n' "$have" "$want" | sort -V | head -1)" = "$have" ]; }; then
  echo "Installing the preview extension $want (installed: ${have:-none}) ..."
  "$root/scripts/build-vscode-preview.sh"
fi

listener() { lsof -nP -t -iTCP:$port -sTCP:LISTEN 2>/dev/null | head -1 || true; }

renders_root() {
  ps eww -o command= -p "$1" | tr ' ' '\n' | grep -qxF "WINDSOR_DOCS_PATH=$root"
}

# The pid file holds the process group id of a server this script started.
started_here() {
  [ -f "$pidfile" ] || return 1
  [ "$(ps -o pgid= -p "$1" | tr -d ' ')" = "$(cat "$pidfile")" ]
}

start_server() {
  mkdir -p "$state"
  echo "Starting the dev server from $site (log: $log) ..."
  # Job control puts the server in its own process group, so stopping it
  # later also stops the vendor watcher and astro under npm.
  set -m
  (cd "$site" && WINDSOR_DOCS_PATH="$root" exec nohup npm run dev </dev/null >"$log" 2>&1) &
  echo $! >"$pidfile"
  set +m
  disown
  for _ in $(seq 1 120); do
    curl -fs -o /dev/null "$url" && return 0
    sleep 1
  done
  err "the dev server did not serve $url; see $log"
}

pid="$(listener)"
if [ -z "$pid" ]; then
  start_server
elif renders_root "$pid"; then
  echo "Using the dev server on port $port (pid $pid)."
elif started_here "$pid"; then
  echo "Stopping the dev server for the other checkout (pgid $(cat "$pidfile")) ..."
  kill -TERM -- "-$(cat "$pidfile")" 2>/dev/null || true
  for _ in $(seq 1 30); do
    [ -z "$(listener)" ] && break
    sleep 1
  done
  [ -z "$(listener)" ] || err "the old dev server is still on port $port"
  rm -f "$pidfile"
  start_server
else
  echo "error: port $port serves another docs checkout (pid $pid), and this script did not start it." >&2
  echo "hint: Stop that server, then run this script again." >&2
  exit 1
fi

"$code_bin" "$root" "${pages[@]}"
