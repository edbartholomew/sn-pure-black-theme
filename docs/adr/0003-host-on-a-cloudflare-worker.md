# 3. Serve the manifest, stylesheet and plugin zip from one Cloudflare Worker

Date: 2026-11-10

## Status

Accepted

## Context

Standard Notes fetches three files for a plugin, and the platforms treat them differently:

- `url` is the stylesheet. The web and mobile apps store it at install time and load it live on
  every launch. They never check for updates, so a change to the file at that URL is the only way
  they ever see a new release. The desktop app uses it only as a fallback when it has no local
  copy.
- `latest_url` is the manifest. Only the desktop app reads it, when it checks for plugin updates.
  It compares the manifest's `version` with the installed one and, if higher, downloads
  `download_url`.
- `download_url` is a zip for the desktop app. It must contain a `package.json` with a `version`
  and an `"sn": { "main": "dist/theme.css" }` entry pointing at the stylesheet. Desktop serves the theme
  from the unpacked copy under its Extensions folder. The desktop app takes `download_url` from the
  manifest it has just fetched, not from the one stored at install. Web and mobile never download
  it.

What the host has to get right:

- **Content types.** Browsers refuse a cross-origin stylesheet that is not served as `text/css`.
  The web app's install dialog only parses the manifest if it is served as `application/json`.
  Anything else fails silently.
- **Client caching, not just CDN caching.** The desktop app fetches with Electron's `net.request`,
  which honours `Cache-Control` like a browser, and a CDN purge cannot reach a copy a client has
  already stored. All three files must be served with a short or zero client cache, and the host
  must not depend on purging. This matters for the zip as well as the manifest. A moving zip URL
  with a cacheable response would hand a desktop the previous release's zip when a new version
  appears.
- A release should be visible on next app load, not after a cache expires.
- The URLs in `ext.json` should not contain a version. Otherwise every release has to rewrite the
  URLs in `ext.json`, not just its version.

Hosts ruled out:

1. **Raw GitHub** (`raw.githubusercontent.com`). It serves everything as `text/plain`, so the
   stylesheet and the manifest both fail.
2. **jsDelivr** with versioned paths. It needs a version in every URL, so the release job has to
   push an `ext.json` rewrite and a built `dist/` onto the release PR, and a cache purge after each
   release. Its branch URLs send `max-age=604800`, so a desktop that had fetched the manifest kept
   its copy for up to a week, purge or not.
3. **raw.githack.com** with a moving `latest` tag. It sends the right content types with
   `no-store` and re-checks GitHub every 60 seconds, but it still needs `dist/` committed, a
   force-moved tag, and a sync job that can race with a fast merge of the release PR. Its FAQ also
   says that heavy traffic from one referring domain is redirected to its CDN host, which caches
   for a year, so it is not safe for a stylesheet loaded by every web client.
4. **Cloudflare R2.** A public bucket without a custom domain is served from a generated
   `pub-<id>.r2.dev` address. Cloudflare rate-limits that address and says it is for development
   traffic only.
5. **GitHub Releases for the zip**, with the manifest and stylesheet elsewhere. GitHub's
   automatic source archive is the repo tree, so it only works if `dist/` is committed, and its
   URL contains the tag, so there is no fixed address for the latest one. A zip attached to each
   release does have one, `releases/latest/download/theme.zip`, but it splits a release across two
   hosts. The zip has to land before the manifest advertises the new version, and if the upload
   fails the tag and release exist with no zip behind them. `releases/latest` also means newest by
   publish date, not highest version.

## Decision

`url`, `latest_url` and `download_url` all point at one assets-only Cloudflare Worker.
`wrangler.toml` declares a `public/` assets directory and nothing else. No code runs at request
time.

The release job builds `dist/theme.css`, zips `package.json` and `dist/theme.css` into
`theme.zip`, copies all three files into `public/`, and publishes them with one `wrangler deploy`.

## Consequences

- A deploy replaces all three files together, so the manifest never advertises a version whose
  stylesheet or zip is missing, and the release job has no ordering to get right.
- A release either reaches the Worker or it does not. If the deploy fails, the tag and GitHub
  release exist but every app keeps the previous version. Re-running the job finishes the release.
- Cloudflare clears its cache on deploy and serves the assets with
  `cache-control: public, max-age=0, must-revalidate` and an `etag`
  (checked with `curl -sI .../theme.css | grep -i cache-control`), so every fetch is revalidated
  and a release is live at once. Confirmed on desktop and iOS.
- The Worker is created by the first deploy. The only manual setup is two repo secrets,
  `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID`. The release job needs read access to the
  repo and nothing more.
- The URLs never change, so `ext.json` only changes when the version is bumped, and that is done
  by release-please ([ADR 4](0004-release-workflow.md)).
- **The Worker hostname is permanent.** Each install stores `url` and `latest_url` at install time.
  If the hostname changed, every existing install would keep using the old one until the user
  reinstalled the theme.
- GitHub releases carry the changelog and the source archives only.
- `dist/` is not committed, so the built file lives only on the Worker.
- The zip is flat, with `package.json` and `dist/` at the root. `package.json` in the zip
  includes dev tooling fields (scripts, devDependencies). The app only reads `version` and
  `sn.main`, so they are harmless.
- What is live is always the last release.
