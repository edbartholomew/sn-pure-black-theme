#!/bin/sh
# Build dist/theme.css: the upstream Dark theme followed by src/theme.css.
set -e
cd "$(dirname "$0")/.."

# The app's built-in Dark theme, which its code calls Focus
URL="https://raw.githubusercontent.com/standardnotes/app/main/packages/web/src/components/assets/org.standardnotes.theme-focus/index.css"

# Fetch the upstream CSS once and reuse it. Delete dist/upstream.css to refresh it.
mkdir -p dist
[ -f dist/upstream.css ] || curl -fsSL "$URL" -o dist/upstream.css

# Concatenate, with a blank line between in case the upstream file has no trailing newline.
{ cat dist/upstream.css; echo; cat src/theme.css; } > dist/theme.css
echo "Built theme.css"
