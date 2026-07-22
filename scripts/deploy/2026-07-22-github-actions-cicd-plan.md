# Cachet CI/CD implementation plan

**Design:** `scripts/deploy/2026-07-22-github-actions-cicd-design.md`  
**Branch:** `feat/a-cicd`

## Step 1 — Make image builds usable by CI

- Extend `scripts/deploy/build-ovh-images.sh` with an explicit publish switch.
- Preserve production default (`push`) and support PR validation (`load`).
- Reject invalid switch values before contacting Docker or GHCR.
- Add OCI source/revision labels without exposing runtime configuration.

Verification: shell syntax, invalid-input test, and one non-publishing amd64 build.

## Step 2 — Add a bounded remote deploy helper

- Add `scripts/deploy/ci-deploy.sh` accepting exactly one full commit SHA.
- Require root and validate all fixed production paths.
- Gate on SimpleArt health before mutation.
- install the reviewed Compose/cachetctl assets from the uploaded release bundle.
- Atomically update both immutable image tags to the same SHA.
- Invoke the existing `cachetctl deploy` preflight/backup/corpus/smoke sequence.
- Restore the previous tags and attempt one image rollback on failure.
- Never restore/delete persistent data automatically or print runtime secrets.

Verification: shell syntax and pure tests for strict SHA validation and exact
secret-free deployment-env generation. The real manually approved deployment is
the integration test for the health gates and image rollback path.

## Step 3 — Add secret-free PR CI

- Add `.github/workflows/cachet-ci.yml` with narrow path filters and permissions.
- Run Python 3.12 engine tests.
- Run Node 22/pnpm 10.18.3 gateway typecheck and tests.
- Validate shell scripts and render the production Compose file with example env.
- Build both `linux/amd64` images without pushing.
- Pin every external action to a verified full commit SHA.

Verification: local YAML parsing/action lint where tooling is available, followed
by the actual pull-request workflow.

## Step 4 — Add immutable image publication

- Add `.github/workflows/cachet-images.yml` for relevant pushes to `main` and
  manual recovery dispatch.
- Repeat unit/config gates on the merged tree before publishing.
- Authenticate to `ghcr.io/scientivan` with `GHCR_PUSH_TOKEN`.
- Push both images under the identical `sha-<github.sha>` tag and inspect both
  remote manifests.
- Always log out of GHCR on the runner.

Verification: workflow syntax and, after the secret is provisioned, one real
publication from `main`.

## Step 5 — Add manually approved OVH deployment

- Add `.github/workflows/cachet-deploy.yml` with `workflow_dispatch` only.
- Use the `ovh-production` environment and non-cancelling global concurrency.
- Validate the selected SHA is a full hash contained in `origin/main`.
- Confirm both private image manifests before SSH.
- Pin the VPS host key, use a dedicated deploy key, and upload a unique release
  bundle.
- Use transient `GHCR_READ_TOKEN` login, invoke `ci-deploy.sh`, verify Cachet and
  SimpleArt externally, then clean credentials and temporary files in `always()`.

Verification: missing/invalid SHA fails before SSH; a real approved deployment
preserves the corpus and both public health checks.

## Step 6 — Runbook, teardown, and shared-zone review

- Document GitHub Environment variables/secrets and least-privilege PAT links.
- Document the manual release flow and failure recovery.
- Document reversible three-week teardown separately from irreversible data
  deletion.
- Run project tests, shell/static checks, Compose rendering, and diff checks.
- Push `feat/a-cicd`, open a PR, and request Wangsit's CODEOWNER review because
  `.github/workflows/` is a shared zone.

The workflows must not be merged until the required secrets exist or image
publication on `main` would fail immediately.
