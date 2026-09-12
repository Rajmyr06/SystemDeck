#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")"

[[ "$(uname -s)" == "Darwin" ]] || { echo "error: macOS is required" >&2; exit 1; }

for tool in swift plutil iconutil codesign hdiutil ditto shasum; do
  command -v "$tool" >/dev/null 2>&1 || { echo "error: missing $tool" >&2; exit 1; }
done

swift package dump-package >/dev/null
swift test
swift build
plutil -lint Packaging/Info.plist >/dev/null
[[ -d Packaging/AppIcon.iconset ]] || { echo "error: app iconset is missing" >&2; exit 1; }

echo "Validation passed."
