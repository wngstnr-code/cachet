# Cachet · Collateralized First-Seen Certificates for Digital Work

**A certificate that puts money behind its claim.** Creators register their work in the Cachet registry and mint a certificate backed by real collateral. If the work is later proven to be a copy, the payout goes to whoever **holds** the work now, not to the creator who lied.

[![contracts CI](https://github.com/wngstnr-code/cachet/actions/workflows/contracts.yml/badge.svg)](https://github.com/wngstnr-code/cachet/actions/workflows/contracts.yml) · Live on **X Layer Testnet** (chain 1952) · All contracts verified on Sourcify

---

## ⚡ Try it in 60 seconds

Every claim below is a public transaction. You do not need to trust us, or this README.

**Live certificate pages** (static site, reads the chain directly, no backend):

| Page | What it shows |
|---|---|
| [/cert/7](https://cachetprotocol.vercel.app/cert/7) | **ACTIVE** coverage, artwork preview stored entirely on-chain in `tokenURI` |
| [/cert/8](https://cachetprotocol.vercel.app/cert/8) | **REVOKED**: lost a challenge, the claim was paid to the current holder |
| [/cert/9](https://cachetprotocol.vercel.app/cert/9) | Survived a challenge: the challenger's bond was slashed |
| [/cert/999](https://cachetprotocol.vercel.app/cert/999) | Honest not-found state |

**One full Golden Path on-chain** (certificate #5):

1. [Certificate issued to the creator](https://www.okx.com/web3/explorer/xlayer-test/tx/0x3358fa314c481ca891062a87541f1bdda779e908d11bc2dd3ac280712ebd50e5)
2. [Creator sells to a buyer, the guarantee moves with it](https://www.okx.com/web3/explorer/xlayer-test/tx/0xf3064aef507a1b0b387094192417cd0e9b408cc524d7d2a72fc744d057a4f4f5)
3. [Challenger disputes with evidence](https://www.okx.com/web3/explorer/xlayer-test/tx/0x657a04a54bc1fc672e920528ebacfb4deb4d4660a32524a62609bda99669c7ee)
4. [Resolver rules: payout to the **buyer**](https://www.okx.com/web3/explorer/xlayer-test/tx/0xdfb71c2a044bb903fd71642be0abdb75b97a76d3237c24ff9902b576b3b2819d)

---

## The problem

Digital work is trivial to copy, and "certificates of authenticity" are just words: when one turns out to be wrong, nobody pays. The risk lands entirely on the buyer, who has no way to check what a seller's claims are worth.

## How Cachet is different

- **First-seen, not "original".** The registry records when a work was first seen by Cachet, with a timestamp anyone can verify on-chain. We never claim to know the whole internet.
- **Collateralized.** Minting requires a fraud bond and a premium paid into a vault. A wrong certificate costs real money.
- **The guarantee follows the holder.** The certificate is an NFT. Sell the work, transfer the NFT, and the coverage moves with it. At resolution the vault pays `ownerOf(certId)`, never a hardcoded creator.
- **Permissionless challenge.** Anyone can dispute a certificate by posting a bond and evidence. A resolver rules after a public liveness window; a successful challenge revokes the certificate and pays the holder, a failed one forfeits the challenger's bond.

## Golden Path

```
CREATOR                                            BUYER
  │ 1. verify: engine checks the work                │
  │    against the registry -> ORIGINAL              │
  │ 2. certify: pay premium + fraud bond             │
  │    -> certificate NFT minted on-chain            │
  │ 3. sell work + certificate ─────────────────────►│ guarantee moves too
  │                                                  │
CHALLENGER                                           │
  │ 4. "that is a copy!" + 10 USDT bond              │
  │    resolver rules after a public window          │
  │    upheld  -> cert revoked, vault pays 50 USDT ─►│ to the BUYER
  │    dismissed -> challenger bond slashed          │
```

Step 4 is the point: the money lands with the buyer. That single property is what makes the certificate worth something on the secondary market.

## Architecture

```
creator/agent ──x402──► GATEWAY ──► ENGINE (perceptual hashing, verdict)
                          │
                          ▼ (only the gateway can mint)
              ┌─────── CONTRACTS on X Layer ───────┐
              │ Registry · Certificate · Vault ·   │
              │ ChallengeManager                   │
              └───────────────┬────────────────────┘
                              │ read-only, no backend
         WATCH (copy alerts)  ▼
                        CERT PAGE (public proof)
```

| Component | Path | What it does |
|---|---|---|
| Contracts | `contracts/` | Registry (first-seen records), Certificate (ERC-721 carrying coverage), Vault (bonds, premiums, payouts), ChallengeManager (disputes and rulings) |
| Gateway | `apps/server/` | The only mint path. Verifies via the engine, charges via x402, submits transactions, signs Originality Profiles (EIP-712) |
| MCP server | `apps/mcp-server/` | Same capabilities exposed as MCP tools, so AI agents can verify and certify programmatically |
| Engine | `services/engine/` | Content brain: 4-hash perceptual ensemble (hard claim) + embedding tier (advisory). Catches resize, re-compression, grayscale copies |
| Watch | `services/watch/` | Re-scans the registry for copies of watched works, sends webhook alerts with a draft challenge |
| Cert page | `apps/web/` | Public proof page. Static Vite site that reads the chain directly, so nobody has to trust our servers |
| Pre-seed | `scripts/` | Seeds the engine corpus so day-one verdicts mean something |

Deliberate design choice: the cert page has **no backend**. If Cachet's servers disappear tomorrow, every certificate remains verifiable from the chain and Sourcify alone.

## For AI agents (x402 + MCP)

Paid endpoints (`/v1/verify`, `/v1/mint`) answer HTTP **402** with an [x402](https://www.x402.org/) payment envelope (asset, amount, payTo) when called without payment. Agents pay in test USDT and retry; the MCP server wraps the same flow as tools. This makes "verify before you buy" a primitive an agent can execute end-to-end without a human.

## Honest limitations

We sell trust, so the fine print is the product:

- **The registry is our corpus, not the internet.** "First-seen" means first seen by Cachet.
- **Coverage is capped**, and the cap differs per deployment: **100 USDT** on X Layer Testnet, **2 USDT** on the X Layer mainnet bootstrap. It is an on-chain parameter (`maxDeclaredValue`) and is further bounded by the vault balance — read it from the contract rather than trusting this page. A claim can only ever pay what the vault actually holds, so the advertised cap is kept at or below the funded amount.
- **Adjudication is a single resolver in this MVP**, constrained by a public liveness window and published admissible-evidence rules ([`contracts/RESOLVER.md`](contracts/RESOLVER.md)). Trustless adjudication it is not, yet — the roadmap is a decentralized oracle set (3+ independent resolvers), not a single key.
- **The embedding tier is advisory.** Only the deterministic perceptual-hash ensemble backs hard claims; there is no "AI detector" here.
- Everything runs on **X Layer Testnet** with a test USDT token.

## Security invariants (each one has a test)

| Invariant | Proven in |
|---|---|
| Payout always goes to `ownerOf(certId)` at resolution, never to a parameter | [`contracts/test/Integration.t.sol`](contracts/test/Integration.t.sol) |
| No mint path except the gateway; no revoke/payout path except ChallengeManager | [`contracts/test/CachetRegistry.t.sol`](contracts/test/CachetRegistry.t.sol) |
| The vault never transfers more than its balance: partial payout + event, not a locking revert | [`contracts/test/CachetVault.t.sol`](contracts/test/CachetVault.t.sol) |
| Waiting period and coverage window are enforced on-chain, assessed when a challenge is **opened** | [`contracts/test/ChallengeManager.t.sol`](contracts/test/ChallengeManager.t.sol) |
| Challenger bonds are earmarked, never spendable as claim liquidity | [`contracts/test/CachetVault.t.sol`](contracts/test/CachetVault.t.sol) |

## Contracts (X Layer Testnet, chain 1952)

| Contract | Address | Verified source |
|---|---|---|
| CachetRegistry | [`0x60BE…9069`](https://www.okx.com/web3/explorer/xlayer-test/address/0x60BEB9aAF8Bf6066A183F99702A403fAfaD19069) | [Sourcify](https://repo.sourcify.dev/1952/0x60BEB9aAF8Bf6066A183F99702A403fAfaD19069) |
| CachetCertificate | [`0xBB0a…7043`](https://www.okx.com/web3/explorer/xlayer-test/address/0xBB0a921b0C575114B6CbBD7c6E8529855B697043) | [Sourcify](https://repo.sourcify.dev/1952/0xBB0a921b0C575114B6CbBD7c6E8529855B697043) |
| CachetVault | [`0x79e9…8834`](https://www.okx.com/web3/explorer/xlayer-test/address/0x79e959A25aF30e01D0bc9e52C693D92e02C28834) | [Sourcify](https://repo.sourcify.dev/1952/0x79e959A25aF30e01D0bc9e52C693D92e02C28834) |
| ChallengeManager | [`0x8BF7…E664`](https://www.okx.com/web3/explorer/xlayer-test/address/0x8BF7551F7e9CB432EbA5fFC21972Bce7f509E664) | [Sourcify](https://repo.sourcify.dev/1952/0x8BF7551F7e9CB432EbA5fFC21972Bce7f509E664) |
| MockUSDT (pay token, 6 decimals) | [`0x9ad1…fa40`](https://www.okx.com/web3/explorer/xlayer-test/address/0x9ad14e783DCe270BE1214153E940aa686f91fa40) | [Sourcify](https://repo.sourcify.dev/1952/0x9ad14e783DCe270BE1214153E940aa686f91fa40) |

Parameters live on-chain and are readable by anyone. On **testnet** (above): premium 2% of declared value, fraud bond 5 USDT, challenge bond 10 USDT, coverage cap 100 USDT. The **mainnet bootstrap** deployment runs the same contracts with smaller, fully funded numbers: fraud bond 1 USDT, challenge bond 1 USDT, coverage cap 2 USDT, premium unchanged at 2%.

## Run it yourself

```bash
# Contracts: build + full test suite
cd contracts && make test

# Full on-chain demo, one command (mint -> sell -> challenge -> payout):
make demo-all          # needs the role keys in the root .env

# Cert page, local dev:
cd apps/web && npm install && npm run dev

# Engine + gateway (see each folder's README for details):
cd services/engine && ENGINE_EMBEDDER=fake ./.venv/bin/python -m app.main
cd apps/server && pnpm install && pnpm start
```

One `.env` at the repo root configures everything; copy `.env.example` to start. Each folder has its own README with specifics.

## Repo layout

```
contracts/   Solidity (Foundry): 4 core contracts, tests, deploy & demo scripts
apps/        server (gateway + x402) · mcp-server (agent tools) · web (cert page)
services/    engine (originality brain) · watch (copy alerts)
scripts/     corpus pre-seed + demo fixtures
packages/    contracts-abi: ABIs + deployed addresses (the on-chain/off-chain contract)
```

## Team

Built by [**@scientivan**](https://github.com/scientivan) (off-chain brain: engine, gateway, watch) and [**@wngstnr-code**](https://github.com/wngstnr-code) (on-chain + proof page: contracts, cert page), pair-programming with two AI agents in one monorepo.
