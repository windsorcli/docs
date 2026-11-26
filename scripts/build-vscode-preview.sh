#!/usr/bin/env bash
#
# Package tools/vscode-preview as a VSIX and install it into VS Code.
#
# A VSIX is a zip with two metadata files at its root, [Content_Types].xml
# and extension.vsixmanifest, and the extension itself under extension/.
# This script writes both files from package.json and zips them, so the
# build has no npm or network step (vsce is not required).
#
#   scripts/build-vscode-preview.sh            # build and install
#   scripts/build-vscode-preview.sh out.vsix   # build to out.vsix only
#
# Finds `code` on PATH, then falls back to the macOS app bundle.

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
src="$root/tools/vscode-preview"

field() {
  node -p "const p = require(process.argv[1]); String($1)" "$src/package.json"
}

name="$(field p.name)"
publisher="$(field p.publisher)"
version="$(field p.version)"
display="$(field p.displayName)"
description="$(field p.description)"
engine="$(field p.engines.vscode)"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

mkdir -p "$work/pkg/extension"
cp "$src/package.json" "$src/extension.js" "$work/pkg/extension/"

cat >"$work/pkg/[Content_Types].xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension=".json" ContentType="application/json"/><Default Extension=".js" ContentType="application/javascript"/><Default Extension=".vsixmanifest" ContentType="text/xml"/></Types>
EOF

cat >"$work/pkg/extension.vsixmanifest" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<PackageManifest Version="2.0.0" xmlns="http://schemas.microsoft.com/developer/vsx-schema/2011" xmlns:d="http://schemas.microsoft.com/developer/vsx-schema-design/2011">
  <Metadata>
    <Identity Language="en-US" Id="$name" Version="$version" Publisher="$publisher"/>
    <DisplayName>$display</DisplayName>
    <Description xml:space="preserve">$description</Description>
    <Properties><Property Id="Microsoft.VisualStudio.Code.Engine" Value="$engine"/></Properties>
  </Metadata>
  <Installation><InstallationTarget Id="Microsoft.VisualStudio.Code"/></Installation>
  <Dependencies/>
  <Assets><Asset Type="Microsoft.VisualStudio.Code.Manifest" Path="extension/package.json" Addressable="true"/></Assets>
</PackageManifest>
EOF

vsix="${1:-$work/$name-$version.vsix}"
case "$vsix" in /*) ;; *) vsix="$PWD/$vsix" ;; esac
rm -f "$vsix"
(cd "$work/pkg" && zip -qrX "$vsix" '[Content_Types].xml' extension.vsixmanifest extension)

if [ -n "${1:-}" ]; then
  echo "Built $vsix"
  exit 0
fi

code_bin="$(command -v code || true)"
[ -n "$code_bin" ] || code_bin="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
[ -x "$code_bin" ] || { echo "error: VS Code's code command was not found." >&2; exit 1; }

"$code_bin" --install-extension "$vsix" --force
