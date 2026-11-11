# 1. Local development tooling

Date: 2026-11-07

## Status

Accepted

## Context

The theme is two files, `ext.json` (the manifest) and `src/theme.css` (our overrides on top of the
app's built-in Dark theme, which its code calls Focus). Changes need to be seen in the Standard
Notes desktop app quickly, without going through a release.

Two properties of the app shape the local loop:

- The desktop app installs a plugin from its `download_url` zip and styles from that local copy.
  It only falls back to `url` when it has no local copy (see
  [ADR 3](0003-host-on-a-cloudflare-worker.md)). So installing the production `ext.json` from
  localhost still loads the released CSS, not the working copy.
- The theme stylesheet is loaded by a `<link>` in the app window. A browser live-reload tool cannot
  reach that window, so there is no way to push a reload into the app from outside.

## Decision

- **One shell script to build.** `scripts/build.sh` concatenates the upstream Dark theme CSS and
  `src/theme.css` into `dist/theme.css`. `dist/` is not committed.
- **Upstream CSS is fetched once per session.** `scripts/dev.sh` fetches the Dark theme's stylesheet
  into `dist/upstream.css` when it starts, and `scripts/build.sh` reuses it, so rebuilds on save are
  instant. The release job starts from a clean checkout, so it always fetches.
- **A separate dev manifest.** `ext.dev.json` has its own identifier and name ("Pure Black (dev)")
  and a `url` pointing at `http://localhost:8000/dist/theme.css`. It has no `download_url`, so the
  desktop app never gets a local copy and loads from `url`. It installs alongside the real theme, so
  switching between them is a click and the production install is never touched.
- **`http-server` for serving.** The manifest is fetched by script, so it needs a CORS header. The
  stylesheet is re-read on every reload, so it needs a no-cache header. `http-server`
  gives both with two flags.
- **A polling watcher in shell.** `scripts/dev.sh` rebuilds when `src/theme.css` changes by comparing its
  modification time once a second. No file-watcher tool is installed for this, because the loop is a
  few lines and the build is instant.
- **Reload is manual.** After a save, choose Help → Clear Cache and Reload.

## Consequences

- `npm run dev` is the whole loop. It builds, serves and rebuilds on save.
- The dev manifest only reaches the desktop app. The app is responsive, so mobile layouts are
  checked by narrowing the desktop window. Behaviour specific to iOS, such as touch hover and the
  status bar, still needs a release to check.
