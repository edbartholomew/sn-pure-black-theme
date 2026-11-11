# 4. Releases with release-please and conventional commits

Date: 2026-11-07

## Status

Accepted

## Context

Each release has to bump the version in three places (`package.json`, `ext.json`, `CHANGELOG.md`),
tag the commit, build the theme and its zip, and deploy both with the manifest to the Worker
([ADR 3](0003-host-on-a-cloudflare-worker.md)). Doing this by hand is error-prone.

## Decision

- **release-please** runs on every push to `main`. It reads conventional commit prefixes. `fix:`
  bumps the patch version, `feat:` the minor and `feat!:` the major. Other prefixes such as `chore:`
  do not create a release.
- It opens or updates a single release PR whose one commit bumps the version everywhere. `ext.json`
  is included through `extra-files` in `release-please-config.json`, so no other job touches the PR.
- Merging the PR creates the git tag and the GitHub release. The tag is the bare version (`1.2.3`),
  while the release title GitHub shows is `v1.2.3`.
- A second job, gated on `release_created`, checks out the tag, builds, and publishes the manifest,
  stylesheet and `theme.zip` to the Worker in one deploy.
- **commitlint with a husky `commit-msg` hook** enforces the conventional format locally, so a
  wrongly prefixed commit is caught before it reaches `main` and silently fails to release.

## Consequences

- A release is two steps. Commit with `fix:` or `feat:`, then merge the release PR.
- The repo setting "Allow GitHub Actions to create and approve pull requests" must be on, or
  release-please fails to open the PR.
- `.release-please-manifest.json` holds the last released version. release-please keeps it in
  step with `package.json`. A new repo starts it as `{}`, which makes the first release 1.0.0.
- The version in `ext.json` and `package.json` always match, which the app requires for update
  detection.
