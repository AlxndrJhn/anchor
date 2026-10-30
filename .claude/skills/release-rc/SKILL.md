---
name: release-rc
description: Start a release candidate of the Anchor+ fork from main. Use when the user writes "release rc" (or asks for a release candidate / preview release).
---

# release rc

"release rc" means: run the fork's release workflow on `main` as a release
candidate. The user asking is the go-ahead; don't ask again.

A candidate is a GitHub prerelease tagged `fork-<version>.<run>`, with the
APKs and desktop installers that changed, and the Docker image pushed as
`ghcr.io/alxndrjhn/anchor:fork-preview` (not `:fork-latest`). The apps only
offer it when "Receive preview releases" is on in their settings (Android:
Settings › Updates; desktop: File / Anchor+ menu › Receive Preview Releases)
and their server runs the `:fork-preview` image, which says so in
`/api/health` (`image`). See the header of `.github/workflows/release-fork.yml`.

1. It builds what is on GitHub's `main`, not the local checkout. Compare
   `git fetch origin main` with the local `main`; if local `main` has commits
   that aren't pushed, tell the user and ask whether to push first.
2. Start it:

   ```bash
   gh workflow run release-fork.yml --repo AlxndrJhn/anchor --ref main -f candidate=true
   ```

3. Find the run and give the user its link:

   ```bash
   gh run list --repo AlxndrJhn/anchor --workflow release-fork.yml --limit 1 --json url,status,createdAt
   ```

Don't wait for or poll the run; it takes about 30–45 minutes. If the user
asks later, `gh run view <id> --repo AlxndrJhn/anchor` shows how it went, and
the release appears under Releases marked "Pre-release", titled
"Anchor+ fork-… (release candidate)".

A normal release is the same command without `-f candidate=true` (or
`-f candidate=false`); it also refreshes `:fork-preview`, so preview servers
never run something older than the release.
