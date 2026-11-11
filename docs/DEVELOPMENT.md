# Development

Two files matter, `ext.json` (the manifest) and `src/theme.css` (our overrides).

`dist/theme.css` is the upstream Standard Notes Dark theme followed by `src/theme.css`, built by
`./scripts/build.sh`. It is generated, not committed. Run the script to test locally. The release
job builds it for publishing.

The app's code calls the Dark theme Focus. Its identifier is `org.standardnotes.theme-focus`, which
is the folder `scripts/build.sh` fetches from. These docs use the name the app shows, Dark.

The reasoning behind the setup is recorded in [adr/](adr/).

## Local loop

`ext.dev.json` is a second manifest for a separate "Pure Black (dev)" theme that loads its CSS
from `http://localhost:8000/dist/theme.css`. It has no `download_url`, so the desktop app loads
from that URL instead of installing a release zip. It sits next to the real theme in the
quick settings menu, so switching between them is a click and the production install is untouched.

1. Start the dev server. It builds once, then rebuilds whenever `src/theme.css` is saved:
   ```
   npm run dev
   ```
2. Once only, go to Standard Notes desktop → Preferences → Plugins → Install Custom Plugin:
   ```
   http://localhost:8000/ext.dev.json
   ```
3. Open the quick settings menu and select "Pure Black (dev)".
4. After saving `src/theme.css`, choose Help → Clear Cache and Reload.

`scripts/dev.sh` fetches the upstream CSS into `dist/upstream.css` when it starts and reuses it for
each rebuild. Restart it to pick up upstream changes.

The dev manifest only reaches the desktop app. Mobile is checked by narrowing the desktop window
into the responsive layout. A full check on a phone is done after a release.

## Writing CSS

- Put palette changes in the `:root` block of `src/theme.css`.
- Override the app's `--sn-stylekit-*` variables first. Use element hooks (ids, data attributes,
  Tailwind classes) only where no variable exists. This is the same pattern as the app's own
  first-party Proton theme.
- Whatever feeds `--sn-stylekit-background-color` at `:root` must be `#hex` or `rgb()`. The app
  parses that one value and throws on keywords, `hsl()` and `color-mix()`, which breaks the iOS
  status bar and theme-colour sync. Anywhere else, including scoped overrides, use what you like.
- Native CSS nesting (`&.selected { … }`) and `color-mix()` are fine. The app supports them and
  there is no build step to transpile anyway.
- If an element does not pick up a colour, check the current variable names in the app source,
  [`_colors.scss`](https://github.com/standardnotes/app/blob/main/packages/styles/src/Styles/_colors.scss)
  and [`_theme.scss`](https://github.com/standardnotes/app/blob/main/packages/web/src/stylesheets/_theme.scss)
  in [standardnotes/app](https://github.com/standardnotes/app).

## Release

Releases are driven by [release-please](https://github.com/googleapis/release-please-action) from
`.github/workflows/release.yml`.

1. Commit to `main` with a conventional prefix, one of `fix:` (patch), `feat:` (minor) or `feat!:`
   (major). Other prefixes such as `chore:` do not trigger a release. A `commit-msg` hook enforces
   the format.
2. release-please opens or updates a "Release" PR. Its single commit bumps the version in
   `package.json`, `ext.json` and `CHANGELOG.md`. Nothing else touches the PR, so merge it when
   ready.
3. Merge the PR. release-please tags the merge commit (plain `1.2.3`) and creates the GitHub
   release. The workflow then builds `dist/theme.css`, zips it with `package.json` as `theme.zip`,
   and deploys `ext.json`, `theme.css` and `theme.zip` to the Cloudflare Worker in one go, so the
   manifest never advertises a version whose zip is missing.

### Hosting

- `url`, `latest_url` and `download_url` point at an assets-only Cloudflare Worker
  (`wrangler.toml`) that serves exactly three files, `theme.css`, `ext.json` and `theme.zip`. Only
  the release job updates it, so what's live is always the last release. Cloudflare clears its
  cache on deploy and the apps revalidate on every load.
- Nothing is attached to the GitHub release. It carries the changelog only.
- The Worker hostname is permanent. Every install stores these URLs at install time, and only a
  desktop update rewrites them. Changing the hostname would strand existing installs until they
  reinstall.

Each app reads different files. Desktop polls `latest_url` and installs from `download_url`. Web
and mobile store `url` at install and load it live, never checking `latest_url`. See
[ADR 3](adr/0003-host-on-a-cloudflare-worker.md).

## One-time setup (for a fork)

- Push to a public GitHub repo, then put the owner/repo into `ext.json`'s `identifier`, and the
  repo name into `package.json`'s `name`.
- In Cloudflare, note your account ID and workers.dev subdomain (Workers & Pages → Overview).
  Create an API token from the "Edit Cloudflare Workers" template. Add both as Actions secrets
  named `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID`. Change the Worker hostname in the URLs
  in `ext.json`, `README.md` and the screenshot snippet below to your own. The Worker is created by
  the first `wrangler deploy`, so nothing is made in the dashboard.
- Allow the workflow to open pull requests, or release-please fails with
  `GitHub Actions is not permitted to create or approve pull requests`. Go to
  Repo → Settings → Actions → General → "Workflow permissions" and tick "Allow GitHub Actions to
  create and approve pull requests".
- `.release-please-manifest.json` holds the last released version. In a new repo leave it as `{}`
  and set `version` to `0.0.0` in `package.json`, `package-lock.json` and `ext.json`. The first
  release PR is then 1.0.0. A real version in the manifest counts as already released, so `1.0.0`
  there would make the first release 1.0.1 or 1.1.0. After that, release-please keeps it in step
  with `package.json` and you never edit it.
- `release-please-config.json` lists `ext.json` under `extra-files` so its version is bumped with
  the rest.

## Checking an install

- The desktop log (update checks and downloads). Look for `PackageManager[Info]`.
   - macOS: `~/Library/Logs/Standard Notes/main.log`
   - Windows: `%APPDATA%\Standard Notes\logs\main.log`
   - Linux: `~/.config/Standard Notes/logs/main.log`

## Preview screenshot

The screenshot in the README is `screenshot.png` in the repo root. Take it in the web app with
example notes.

1. Open the [web app](https://app.standardnotes.com) signed out. Either log out first or use a private window.
2. Create a few example notes.
3. Open the browser's developer tools and run this in the console to load the stylesheet, with
   `href` set to the `url` value from `ext.json`.
   ```js
   const l = document.createElement('link');
   l.rel = 'stylesheet';
   l.href = 'https://sn-pure-black-theme.edbartholomew.workers.dev/theme.css';
   document.head.appendChild(l);
   ```
4. Take the screenshot. The theme lasts until the page is reloaded.
