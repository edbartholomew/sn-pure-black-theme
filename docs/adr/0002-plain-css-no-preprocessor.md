# 2. Plain CSS, no preprocessor or PostCSS

Date: 2026-11-07

## Status

Accepted

## Context

The theme is a short stylesheet of overrides on top of the upstream Dark theme. It needs:

- Variables, to define a palette once and reuse it
- Nesting, to keep related rules together
- Some colour maths, for example the selected-row tint derived from the accent colour
- Concatenation with the upstream stylesheet into one file

A preprocessor such as Sass, a PostCSS pipeline with a nesting plugin, or a minifier such as
cssnano would each bring a dependency tree, a config file and a build step larger than the theme
itself, and a Makefile or task runner to drive them. Minification in particular gains nothing here,
because the file is a few kilobytes, served once per app load and cached.

The app runs in Chromium on desktop (Electron) and WebKit on iOS, and its own stylesheets already
rely on modern CSS. The features above all exist natively as custom properties, CSS nesting with `&`
and `color-mix()`.

One constraint comes from the app rather than the browser. After a theme loads, the app reads the
computed value of `--sn-stylekit-background-color` on `<html>` and parses it with a small colour
class that accepts only `#hex` and `rgb()`/`rgba()`. Anything else (`black`, `hsl()`,
`color-mix()`) throws.

## Decision

Write the theme as plain CSS and use the browser's own features for variables, nesting and colour
mixing. The only "build" is `scripts/build.sh`, which concatenates the upstream stylesheet and
`src/theme.css`. No npm package is involved in producing the theme.

Whatever feeds `--sn-stylekit-background-color` at `:root` is written as `#hex`. `hsl()` and
`color-mix()` are used freely everywhere else.

## Consequences

- No preprocessor syntax to learn, no node_modules needed to build, and the file in the repo is the
  file the app loads.
- The built file has two `:root` blocks, upstream's and ours. The cascade resolves them exactly as
  one merged block would, so they are left as they are. Merging them would need a PostCSS step for
  a cosmetic result.
- There is no autoprefixing or transpiling. If a feature is missing in the app's WebView on some
  platform, the rule is rewritten to avoid it rather than compiled down. Nothing has needed this so far.
- There is no CSS linting. The file is small enough to review by eye.
- The dev dependencies in `package.json` (commitlint, husky) exist for commit hygiene, not for
  building the theme. See [ADR 4](0004-release-workflow.md).
