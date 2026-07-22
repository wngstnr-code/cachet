# OKX x402 v2 Integration Implementation Plan

**Date:** 2026-07-22  
**Branch:** `feat/a-okx-x402-v2`  
**Design:** `docs/superpowers/specs/2026-07-22-okx-x402-v2-design.md`

## Goal

Replace the custom x402 v1 guard in the Cachet Fastify gateway with the official
OKX x402 v2 Fastify SDK, preserve the current protected routes and prices, and
prepare a safe gateway-only OVH deployment for the public X Layer Testnet smoke
test.

## Task 1: Pin and inspect the official SDK

Files:

- Modify `apps/server/package.json`
- Modify `apps/server/pnpm-lock.yaml`

Steps:

1. Query the current published versions of `@okxweb3/x402-fastify`,
   `@okxweb3/x402-core`, and `@okxweb3/x402-evm`.
2. Install the three packages from the registry in `apps/server`.
3. Inspect their installed exports and TypeScript declarations for the exact
   Fastify middleware, facilitator client, resource server, route config, and
   EVM exact-scheme constructors.
4. Record only package/API facts needed by the implementation; do not copy or
   expose runtime secrets.

Verification:

- `pnpm install --frozen-lockfile` succeeds in `apps/server` after the lockfile
  update.

## Task 2: Define strict runtime configuration

Files:

- Modify `apps/server/src/config.ts`
- Modify `apps/server/test/unit.test.ts` or add a focused config test file

Steps:

1. Add an explicit x402 runtime config object containing bypass, network,
   receiving address, public resource base, OKX base URL, and optional credential
   triplet.
2. Validate that production uses `eip155:1952`, an HTTPS resource base, and a
   valid EVM `payTo` address.
3. When bypass is false, require API key, secret key, and passphrase together.
4. Remove construction of the legacy `HttpFacilitator` and retire
   `X402_FACILITATOR_URL`/`X402_ASSET` from production configuration.
5. Keep tests secret-free by allowing injected payment registration in app tests.

Verification:

- Tests cover bypass-without-credentials, complete credentials, partial
  credentials, invalid network, invalid address, and non-HTTPS production base.

## Task 3: Convert route prices to official SDK route configuration

Files:

- Modify `apps/server/src/x402/prices.ts`
- Replace `apps/server/src/x402/requirements.ts` with an SDK route-config adapter
- Modify `apps/server/test/x402.test.ts`

Steps:

1. Preserve the four existing route keys and descriptions.
2. Represent prices as `$0.02`, `$0.01`, `$0.50`, and `$0.10`.
3. Generate SDK route entries with `exact`, `eip155:1952`, public resource URLs,
   descriptions, JSON MIME type, timeout, and the configured receiving address.
4. Ensure free endpoints never appear in the protected route map.

Verification:

- Unit tests assert all four mappings, exact price strings, public HTTPS resource
  URLs, and free-route exclusion.

## Task 4: Replace the custom payment guard

Files:

- Replace `apps/server/src/x402/plugin.ts`
- Remove `apps/server/src/x402/guard.ts`
- Modify `apps/server/src/app.ts`
- Modify `apps/server/test/helpers.ts`
- Modify `apps/server/test/x402.test.ts`

Steps:

1. Build an authenticated `OKXFacilitatorClient` from runtime config.
2. Build and initialize the SDK resource server.
3. Register the EVM `exact` server scheme for the configured testnet network.
4. Register official Fastify payment middleware for the generated route map.
5. Provide a narrow injectable registrar boundary so unit tests can assert
   paid/unpaid handler behavior without external network calls.
6. Remove all hand-built v1 payload, `/verify`, `/settle`, `X-PAYMENT`, and custom
   base64 response logic.
7. Preserve fail-closed behavior and existing Cachet business error handling.

Verification:

- Unpaid requests produce a v2 `PAYMENT-REQUIRED` challenge.
- Accepted fake payments reach the handler, settle after a successful response,
  and return a receipt.
- Rejected payments and fake Broker failures do not reach the handler.
- Business responses with status 400 or higher are not settled.
- Free routes remain available.

## Task 5: Update the MCP adapter contract

Files:

- Modify `apps/mcp-server/src/gateway.ts` if response metadata changes
- Modify `apps/mcp-server/src/tools.ts`
- Modify `apps/mcp-server/test/tools.test.ts`
- Modify `apps/mcp-server/README.md`

Steps:

1. Preserve transparent passthrough of `PAYMENT-REQUIRED` from the REST gateway.
2. Update the buyer retry hint from legacy `X-PAYMENT` wording to the standard v2
   payment header terminology.
3. Update fixtures from x402 v1 to v2.
4. Keep the MCP server as a non-public thin adapter; do not add a new transport or
   payment authority.

Verification:

- MCP tests pass and expose the v2 challenge without fabricating payment success.

## Task 6: Update environment and deployment documentation

Files:

- Modify `.env.example`
- Modify `scripts/deploy/ovh.runtime.env.example`
- Modify `apps/server/README.md`
- Modify `scripts/deploy/README.md`
- Modify `be-tracker.md` locally only

Steps:

1. Add `OKX_API_KEY`, `OKX_SECRET_KEY`, `OKX_PASSPHRASE`, `OKX_BASE_URL`, and
   `X402_RESOURCE_BASE` placeholders.
2. Remove deprecated facilitator URL and custom x402 asset instructions.
3. Document that production secrets are entered directly with `sudoedit`, never
   committed or pasted into chat.
4. Document X Layer Testnet scope, official Broker-selected settlement asset, and
   gateway-only deployment/rollback.
5. Update local tracker semantics: D5 credential acquisition complete, M5 code
   completion dependent on tests, A5.4 and post-listing acceptance still open,
   CI/CD still paused.
6. Never stage or commit `be-tracker.md` or `be-plan.md`.

Verification:

- Repository search finds no obsolete production instruction requiring
  `X402_FACILITATOR_URL` or project `X402_ASSET`.
- Diff contains no credential values.

## Task 7: Full local verification

Steps:

1. Run gateway tests and typecheck.
2. Run MCP tests and typecheck.
3. Run deployment preflight/config checks that do not require production secrets.
4. Build the gateway Docker image for `linux/amd64`.
5. Inspect the final diff, staged file list, and secret patterns while explicitly
   excluding `.env`.
6. Commit implementation files only.

Success criteria:

- All relevant tests/typechecks pass.
- Docker build succeeds.
- No production secret appears in tracked files or command output.
- CI/CD files are unchanged.

## Task 8: OVH deployment and A5.4 smoke test

This task starts only after local verification and requires user-controlled secret
entry.

Steps:

1. Build/publish or transfer the immutable gateway image using the existing manual
   deployment runbook; do not resume CI/CD.
2. Have the user enter the new credential triplet directly into
   `/opt/cachet/.env` with `sudoedit`.
3. Recreate only the Cachet gateway container.
4. Confirm health, free certificate lookup, and compliant public unpaid 402.
5. Fund a separate buyer wallet from the official X Layer Testnet faucet.
6. Execute direct paid verify and mint calls through an OKX-compatible buyer.
7. Verify the Originality Profile, payment receipt/transaction, minted NFT, and
   SimpleArt health.
8. Roll back only the gateway image if any gate fails.

Completion semantics:

- D5 is complete when credentials are obtained and the gateway can authenticate
  to the OKX Broker.
- M5 is complete when the official SDK integration is tested and deployed.
- A5.4 is complete only after the public paid testnet flow succeeds.
- Final marketplace acceptance remains open until the same flow succeeds through
  the accepted OKX.AI listing.
