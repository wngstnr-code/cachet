# Cachet on the shared SimpleArt OVHcloud VPS — deployment design

**Date:** 2026-07-22  
**Status:** Approved design  
**Owner:** Person A (Dien, off-chain services)

## 1. Context and constraints

Cachet will run on the same OVHcloud VPS that already serves the production
SimpleArt website at `simpleartch.com`. The VPS has 2 vCore, 4 GB RAM, and
40 GB NVMe storage. SimpleArt remains the priority workload.

The public Cachet hostname is `api.cachetprotocol.xyz`. The domain is registered
at Dynadot and will use Cloudflare DNS, proxying, and public TLS. Cloudflare R2
is not part of this deployment.

This design must satisfy the following constraints:

- SimpleArt must have no planned downtime during a Cachet deployment.
- Cachet may be stopped briefly while SimpleArt performs a blue-green deploy.
- Cachet images are built outside the VPS; the VPS only pulls immutable images.
- Only the gateway is reachable through the public hostname.
- Engine and gateway state must survive container replacement and host reboot.
- `X402_BYPASS=0` and `DEMO_MODE=0` are mandatory.
- Person A deployment work stays inside `services/engine/`, `apps/server/`, and
  `scripts/`; the SimpleArt repository is not edited from this workstream.

## 2. Scope

The initial production stack contains only:

1. `cachet-engine`: Python FastAPI originality engine.
2. `cachet-gateway`: Node/Fastify public API, signer, x402 guard, and chain client.

The Watch worker and stdio MCP container are excluded to conserve resources.
External MCP clients continue to reach the REST gateway through the existing MCP
wrapper on the client side. Adding Watch later requires a separate design because
its current implementation shares the gateway JSON store.

## 3. Architecture

```text
Internet / okx.ai / external MCP client
                    |
                    | HTTPS
                    v
          Cloudflare DNS + Proxy + TLS
                    |
                    | HTTPS (Full strict)
                    v
             Caddy on OVHcloud VPS
                    |
                    | 127.0.0.1:8787
                    v
            Cachet gateway container
                    |
                    | private Docker network
                    v
             Cachet engine container
```

SimpleArt retains its existing Caddy upstream and blue-green containers. Cachet
uses its own Compose project, Docker network, environment file, data directories,
and image lifecycle.

### Network exposure

- Caddy is the only process accepting public HTTP/HTTPS traffic on ports 80/443.
- Gateway publishes `8787` only on host loopback:
  `127.0.0.1:8787:8787`.
- Engine is reachable from gateway as `http://engine:8100` on the private Cachet
  Docker network.
- Engine may publish `8100` on host loopback only during initial corpus seeding.
  Administration reaches it through an SSH local-forward; it is never bound to
  the VPS public interface.
- UFW does not open ports 8100 or 8787.

## 4. DNS and TLS

`cachetprotocol.xyz` is added as a separate Cloudflare zone. Dynadot delegates the
domain to the Cloudflare-assigned nameservers. Cloudflare has a proxied `A` record
for `api.cachetprotocol.xyz` whose target is the VPS's actual public IPv4. The
IPv4 is operational configuration entered in the Cloudflare dashboard and is
never committed.

Cloudflare SSL/TLS mode is `Full (strict)`. A distinct Cloudflare Origin CA
certificate covering `api.cachetprotocol.xyz` is installed on the VPS under a
root-owned directory with group-read access only for Caddy. Its private key is
never stored in either repository.

Caddy routes by explicit hostname. Before the first Cachet route is added, the
effective SimpleArt Caddy configuration is inspected. If SimpleArt still uses a
catch-all HTTPS site address, it is narrowed to `simpleartch.com` and
`www.simpleartch.com` so it cannot capture the Cachet hostname. Every Caddy change
must pass `caddy validate` and is applied with a graceful reload, not a restart.

The Cachet repository supplies a Caddy snippet for the operator to integrate into
the host-owned configuration; it does not modify the SimpleArt repository.

## 5. Resource budget

The production Compose configuration enforces these initial ceilings:

| Service | Memory ceiling | CPU ceiling |
|---|---:|---:|
| Engine | 900 MB | 0.65 vCPU |
| Gateway | 450 MB | 0.35 vCPU |
| **Cachet total** | **1.35 GB** | **1.00 vCPU** |

Both services have PID limits, dropped Linux capabilities, `no-new-privileges`,
bounded JSON logs, health checks, and `restart: unless-stopped`. Limits are
adjusted only from observed metrics, not removed to fix an unexplained failure.

The host has a 2 GB swap file with low swappiness as an OOM safety net. Swap is
not treated as application RAM. Cachet is stopped before a SimpleArt blue-green
deployment so SimpleArt may temporarily run both application slots safely.

## 6. CLIP decision and upgrade trigger

CLIP is intentionally not installed on this VPS deployment:

```text
ENGINE_EMBEDDER=fake
WITH_ML=0
```

The deterministic four-pHash tier remains active. Embedding output is not a
production similarity signal and must continue to be described as advisory.

Before enabling CLIP, Dien must either:

1. upgrade the shared VPS to at least 4 vCore and 8 GB RAM; or
2. move Cachet to a separate host with equivalent or greater capacity.

After either change, build the ML image with `WITH_ML=1`, set
`ENGINE_EMBEDDER=clip`, and benchmark memory, startup time, and query latency
before exposing it to public traffic. CLIP must never be enabled merely by
changing the environment variable on the current non-ML image.

## 7. Images and container security

Production images use immutable commit-SHA tags:

```text
ghcr.io/wngstnr-code/cachet-engine:sha-${GIT_COMMIT}
ghcr.io/wngstnr-code/cachet-gateway:sha-${GIT_COMMIT}
```

`GIT_COMMIT` is the full 40-character commit ID being released; it is resolved by
the build command and is never a mutable label such as `latest`.

They are built on Dien's Mac or CI and pushed to GHCR. The VPS does not run
`docker build`, `pip install`, or `pnpm install`. Registry credentials on the VPS
are read-only package credentials.

Both Dockerfiles use pinned major runtime images, copy only runtime inputs, and
run under dedicated non-root users. Secrets are supplied only at runtime. No
private key, `.env`, contract credential, or Cloudflare credential enters a build
argument, image layer, or build log.

## 8. Persistent state and backup

Runtime configuration is installed at:

```text
/opt/cachet/compose.yml
/opt/cachet/.env             # root-owned, mode 0600
/opt/cachet/deploy.env       # immutable image tags, no private keys
```

Persistent state is stored outside the application checkout:

```text
/var/lib/cachet/engine       # /data in engine; SQLite under /data/index
/var/lib/cachet/gateway      # /data in gateway; gateway.json
```

Bind mounts are used so ownership, disk usage, backup, and recovery are explicit.
The directories are writable only by their container service UIDs and the host
administrator.

Before each deployment, the operator creates a timestamped local backup under
`/var/backups/cachet/`. The engine backup uses SQLite's backup mechanism rather
than copying a live WAL database blindly; gateway state is safe to copy because
it is written atomically. Local backups are rotated to fit the 40 GB disk. An
OVHcloud host backup, when enabled, is a second recovery layer but is not a
substitute for the pre-deploy application backup.

The initial 5k synthetic corpus is seeded once through an SSH tunnel to the
loopback-only engine port. The seed process is complete only when `/healthz`
reports the expected entry count. Subsequent deploys reuse the existing SQLite
database and never reseed automatically.

## 9. Deployment coordination

### Cachet deployment

1. Run engine tests, gateway tests/typecheck, and local container smoke tests.
2. Build and push both images with the same Git SHA tag.
3. Record current production tags and create application-state backups.
4. Pull the new engine image; recreate only engine.
5. Wait for engine health and verify the corpus entry count.
6. Pull the new gateway image; recreate only gateway.
7. Run internal and external smoke tests.
8. Retain the previous image tags for rollback.

After the initial Caddy route exists, routine Cachet deployments do not reload
Caddy and create no planned SimpleArt downtime. Pulls and container replacement
are performed one service at a time to limit I/O and memory spikes.

### SimpleArt deployment

1. Record Cachet health, then stop the Cachet Compose project.
2. Run the existing SimpleArt blue-green deployment and health checks.
3. Confirm `https://simpleartch.com/api/health` is healthy.
4. Start Cachet again.
5. Confirm engine state, gateway health, and the public Cachet endpoint.

This policy gives SimpleArt priority. Cachet has a planned short outage during a
SimpleArt release, but SimpleArt has no planned outage during a Cachet release.

## 10. Failure handling and rollback

- **New engine unhealthy:** do not replace gateway. Restore the previous engine
  image tag and retain the existing data directory.
- **New gateway unhealthy:** restore the previous gateway image tag; engine may
  remain on the new healthy version only if its API contract is unchanged.
- **State corruption:** stop the affected service, restore the most recent
  consistent application backup, then start and verify it before public traffic.
- **Caddy validation failure:** do not reload Caddy. SimpleArt continues on the
  last valid configuration.
- **Resource pressure:** stop Cachet first. Do not sacrifice SimpleArt availability
  to keep the hackathon service alive.
- **Host reboot:** `restart: unless-stopped` restores both Cachet services after
  Docker starts; external monitoring confirms both public applications recover.

## 11. Verification and acceptance

The deployment is accepted only when all checks pass:

1. `https://simpleartch.com/api/health` is healthy before and after the change.
2. `https://api.cachetprotocol.xyz/healthz` returns HTTP 200 through Cloudflare.
3. Engine `/healthz` is reachable from gateway and through an authenticated SSH
   tunnel, but not from the public internet.
4. An unpaid request to a paid endpoint returns HTTP 402.
5. Runtime inspection confirms `X402_BYPASS=0`, `DEMO_MODE=0`,
   `ENGINE_EMBEDDER=fake`, and `CHAIN_MODE=viem` without printing secrets.
6. A known testnet certificate can be read through the public gateway.
7. Engine entry count and gateway state survive container recreation.
8. Host sockets show no public listener on 8100 or 8787.
9. `docker stats`, restart counts, disk usage, and swap usage stay within the
   approved resource envelope during smoke testing.
10. Rollback to the previous immutable image tags is rehearsed once.

## 12. Planned implementation artifacts

All new or changed files stay in Person A's allowed folders:

- harden `services/engine/Dockerfile` for a small, non-root production image;
- harden `apps/server/Dockerfile` for a small, non-root production image;
- add an OVH production Compose file under `scripts/deploy/`;
- add a secret-free OVH environment template under `scripts/deploy/`;
- add the Cachet Caddy site snippet under `scripts/deploy/`;
- add operator commands for initial provisioning, deploy, pause/resume, backup,
  rollback, and smoke verification under `scripts/deploy/`;
- update `scripts/deploy/README.md` with the shared-VPS runbook and the explicit
  CLIP upgrade warning.

No contract, ABI, certificate-page, SimpleArt, root configuration, or shared
documentation file is modified by this workstream.
