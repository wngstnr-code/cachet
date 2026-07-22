# Cachet GitHub Actions CI/CD for the temporary OVH deployment

**Date:** 2026-07-22  
**Owner:** Person A (Dien)  
**Status:** approved in conversation; written review pending

## 1. Goal and lifetime

Cachet is expected to share the SimpleArt OVH VPS for roughly three weeks around
the OKX hackathon. CI/CD must make backend releases repeatable without turning
this short-lived deployment into a permanent operations platform.

The system will:

- validate Person A code on pull requests;
- publish immutable engine and gateway images after relevant changes reach
  `main`;
- deploy a selected `main` commit only after Dien manually starts and approves a
  production workflow;
- preserve the existing SimpleArt-first resource policy; and
- use the existing pre-deploy application backup instead of scheduled backups.

Scheduled backup rotation, an additional monitoring container, automatic service
healing, and CLIP are deliberately out of scope. Before final teardown, the
operator creates one last application backup and decides whether to download or
delete `/var/lib/cachet` separately from the containers.

## 2. Repository boundaries

Most implementation remains in Person A's `scripts/` directory. Activating
GitHub Actions necessarily adds workflow files below `.github/workflows/`, which
is a shared zone under `CLAUDE.md` and `CODEOWNERS`. The CI/CD pull request must
therefore request Wangsit's review; it must not alter `apps/web/`, `contracts/`,
or `packages/contracts-abi/`.

Proposed units:

| Unit | Responsibility |
| --- | --- |
| `.github/workflows/cachet-ci.yml` | Secret-free PR tests, typecheck, and container build validation |
| `.github/workflows/cachet-images.yml` | Build and push both immutable production images after relevant changes reach `main` |
| `.github/workflows/cachet-deploy.yml` | Manual, protected deployment of an already-published `main` SHA |
| `scripts/deploy/ci-deploy.sh` | VPS-side orchestration with input validation, SimpleArt gates, tag update, deploy, and image rollback |
| `scripts/deploy/README.md` | Secret provisioning, workflow use, incident recovery, and teardown instructions |

The shell helper is independently testable and keeps operational logic out of a
large YAML `run` block.

## 3. Workflow triggers and concurrency

### Pull-request CI

`cachet-ci.yml` runs for pull requests when one of these inputs changes:

- `services/engine/**`;
- `apps/server/**`;
- relevant `packages/contracts-abi/**` inputs read by the gateway;
- `tsconfig.base.json`;
- `scripts/deploy/**`; or
- the Cachet workflow files themselves.

It also runs on relevant pushes to `main`, so the exact merged tree is validated.
Repeated pushes to the same PR cancel the older run. It receives only
`contents: read` and never loads production secrets.

### Image publication

`cachet-images.yml` runs after relevant pushes to `main` and may also be invoked
manually for recovery. It tests the merged tree, logs in to GHCR, and pushes:

```text
ghcr.io/scientivan/cachet-engine:sha-<40-character commit SHA>
ghcr.io/scientivan/cachet-gateway:sha-<same commit SHA>
```

There is no `latest` tag. A concurrency group keyed to the commit prevents
duplicate publication while allowing different commits to finish independently.

### Production deployment

`cachet-deploy.yml` is `workflow_dispatch` only. It accepts a 40-character commit
SHA; when left blank it uses the current commit of the selected `main` ref. The
job rejects commits not contained in `origin/main`, then confirms both GHCR image
manifests exist before connecting to the VPS.

The job uses the protected GitHub Environment `ovh-production`, with Dien as the
required reviewer. Its concurrency group is global (`cachet-ovh-production`) and
does not cancel an in-progress deployment. Two production deploys therefore
cannot overlap.

## 4. Build and test gates

PR and publication workflows use pinned action revisions and explicit toolchain
versions. Their gates are:

1. Engine: Python 3.12, install core requirements, run the engine test suite.
2. Gateway: Node 22 with pnpm 10.18.3, frozen install, typecheck, and tests.
3. Shell/config: `bash -n`, Compose config rendering with the example env, and
   build-script validation.
4. Containers: Build both `linux/amd64` production images with CLIP disabled.
5. Publication only: push both images and inspect their remote manifests.

Build inputs remain secret-free. `.env`, the gateway private key, Cloudflare
certificate material, and VPS runtime configuration never enter BuildKit or
GitHub artifacts.

## 5. Credentials and trust boundaries

The repository belongs to `wngstnr-code`, while the images live under the
personal `ghcr.io/scientivan` namespace. The repository `GITHUB_TOKEN` is not
assumed to have permission to publish those personal packages.

Required GitHub Environment/repository configuration:

| Name | Kind | Scope |
| --- | --- | --- |
| `GHCR_PUSH_TOKEN` | repository secret | dedicated Dien PAT with `write:packages`, not reused for interactive work |
| `GHCR_READ_TOKEN` | `ovh-production` secret | separate PAT with `read:packages` only |
| `OVH_SSH_PRIVATE_KEY` | `ovh-production` secret | dedicated unencrypted deploy key, not Dien's daily SSH key |
| `OVH_HOST` | environment variable | `15.235.146.33` |
| `OVH_USER` | environment variable | `ubuntu` |
| `OVH_SSH_HOST_KEY` | environment variable | pinned public `known_hosts` line for the OVH host |

The deploy job writes the private key to the ephemeral runner with mode `0600`
and constructs `known_hosts` from the pinned key. It never uses
`StrictHostKeyChecking=no`.

The GHCR read token is piped to `docker login --password-stdin` immediately before
deployment and `docker logout ghcr.io` runs in an `always()` cleanup step. The VPS
does not retain registry credentials between deployments. Existing runtime
secrets remain only in root-owned `/opt/cachet/.env` mode `0600`.

## 6. Deployment data flow

1. The workflow validates that the requested SHA belongs to `main` and that both
   image manifests exist.
2. It verifies `https://simpleartch.com/api/health` from the runner.
3. It copies only `compose.ovh.yml`, `cachetctl.sh`, and `ci-deploy.sh` to a unique
   temporary directory on the VPS.
4. The remote helper validates the SHA again, installs the versioned deployment
   assets, and saves the current `/opt/cachet/deploy.env` as a protected rollback
   file.
5. It atomically writes both new image tags with the same SHA.
6. It invokes `cachetctl deploy`, which performs preflight, a consistent SQLite/
   gateway-state backup, image pulls, ordered engine/gateway replacement, the
   5,000-entry corpus gate, and internal/public smoke tests.
7. The workflow verifies both Cachet and SimpleArt from the GitHub runner.
8. It removes the remote temporary directory and logs out of GHCR even on failure.

Routine Cachet deployment does not reload Caddy and does not stop, recreate, or
modify the SimpleArt container.

## 7. Failure handling

- A test or build failure publishes and deploys nothing.
- A missing image manifest stops before SSH.
- A failed SimpleArt precheck stops before changing Cachet.
- A failed Cachet deploy restores the previous immutable image tags and attempts
  one image rollback through `cachetctl deploy`. Persistent data is not
  automatically overwritten; the pre-deploy backup is retained for manual state
  recovery.
- If rollback also fails, the job exits failed, prints only non-secret diagnostic
  commands and backup paths, and leaves SimpleArt untouched.
- A failed post-deploy SimpleArt check marks the workflow failed and requires
  immediate operator investigation; it does not restart SimpleArt automatically.

GitHub Actions logs may show image SHAs, health status, and backup directory names,
but never environment contents, tokens, private keys, or certificate keys.

## 8. Monitoring for the three-week window

No same-host monitoring container is added: it cannot alert when the VPS itself is
down and consumes resources needed by SimpleArt. Docker health checks,
`restart: unless-stopped`, bounded JSON logs, Cloudflare, and post-deploy external
smoke tests remain active.

True outage alerts are optional and require an external account such as
UptimeRobot or Better Stack. If Dien creates one, it should probe:

- `https://api.cachetprotocol.xyz/healthz`; and
- `https://simpleartch.com/api/health`.

This optional account setup is independent of CI/CD acceptance.

## 9. Verification and acceptance

The implementation is accepted when all of the following are demonstrated:

1. A harmless Person A PR runs engine, gateway, shell/config, and image-build
   checks without access to production secrets.
2. A relevant merge to `main` publishes two private images carrying the identical
   full-SHA tag; an unrelated web-only change does not publish backend images.
3. A production deploy cannot start without manual environment approval and
   cannot overlap another deploy.
4. SSH host verification is pinned and the deploy uses a dedicated key.
5. The VPS retains no GHCR login after success or failure.
6. A deployment creates a backup, preserves at least 5,000 corpus entries, and
   returns HTTP 200 from `/healthz`, HTTP 402 for an unpaid verify request, and a
   readable certificate #6 with the Vercel cert-page URL.
7. `https://simpleartch.com/api/health` is healthy before and after deployment.
8. A controlled bad-image rehearsal fails before production mutation, while an
   image rollback rehearsal returns Cachet to the previous SHA without restoring
   or deleting persistent data.

## 10. Teardown after the hackathon

Teardown is a separate manual operation, never a CI trigger. The runbook will
provide two explicit choices:

- **reversible:** final backup, stop/remove only Cachet containers and Caddy route,
  retain `/var/lib/cachet` and the backup archive; or
- **final:** download/verify the final archive, then separately remove Cachet data,
  images, certificates, DNS records, and GitHub deployment secrets after explicit
  confirmation.

Neither option changes the SimpleArt Compose project or its persistent data.
