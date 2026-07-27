<p align="center">
  <img src="cachet-logo.png" alt="Cachet" width="120">
</p>

# Cachet · Collateralized First-Seen Certificates for Digital Work

**A certificate that puts money behind its claim.** Creators register their work in the Cachet registry and mint a certificate backed by real collateral. If the work is later proven to be a copy, the payout goes to whoever **holds** the work now, not to the creator who lied.

[![contracts CI](https://github.com/wngstnr-code/cachet/actions/workflows/contracts.yml/badge.svg)](https://github.com/wngstnr-code/cachet/actions/workflows/contracts.yml) · Live on **X Layer mainnet** (chain 196) and **X Layer Testnet** (chain 1952) · All contracts verified on Sourcify

| | |
|---|---|
| 🤖 **Listed as an ASP** | [okx.ai/agents/7530](https://www.okx.ai/agents/7530) |
| 🔌 **Live API** (x402, mainnet settlement) | `https://api.cachetprotocol.xyz` |
| 🔎 **Certificate pages** (no backend) | [cachetprotocol.vercel.app](https://cachetprotocol.vercel.app) |
| 𝕏 **Launch post + 90s demo** | <!-- TODO: paste X post URL (#OKXAI) --> |

> **Two live deployments, and the difference matters.** Mainnet is the real one: real USD₮0, a vault you cannot refill from a faucet, and a coverage cap sized to what that vault actually holds — **2 USDT** during bootstrap. Testnet is where the walkthrough below lives: the same contracts, but the pay token is `MockUSDT`, which anyone can mint for free. Every worked example on this page is a **testnet** transaction, so read them as a demonstration of the mechanism, not as evidence of collateral.

---

## ⚡ Try it in 60 seconds

Every claim below is a public transaction, or a live endpoint you can hit right now. You do not need to trust us, or this README.

**Make the API charge you** (this is the running mainnet gateway, no signup):

```bash
curl -i -X POST https://api.cachetprotocol.xyz/v1/verify \
     -H 'content-type: application/json' -d '{}'
```

You get `HTTP/2 402` and a `payment-required` header. Base64-decode it and the x402 envelope is real, pointing at the mainnet deployment:

```json
{
  "x402Version": 2,
  "resource": { "url": "https://api.cachetprotocol.xyz/v1/verify",
                "description": "Cachet verify_originality - Originality Profile" },
  "accepts": [{
    "scheme": "exact",
    "network": "eip155:196",
    "amount": "20000",
    "asset": "0x779ded0c9e1022225f8e0630b35a9b54be713736",
    "payTo": "0xa3C3f8eE84a301fc4BD63DD712344d627230514B",
    "maxTimeoutSeconds": 300,
    "extra": { "name": "USD₮0", "version": "1" }
  }]
}
```

`20000` is 0.02 USD₮0 at 6 decimals. An x402-capable agent signs, retries with `PAYMENT-SIGNATURE`, and gets an Originality Profile back. No human in the loop.

---

> The rest of this section is on **X Layer Testnet**. The full Golden Path has been played out end to end there — including a real payout — which is what makes it worth showing. Mainnet contracts are listed further down; they are new, so they have no such history yet.

<!-- TODO: drop a screenshot of /cert/7 into docs/img/ and embed it here -->

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

Paid endpoints (`/v1/verify`, `/v1/mint`) answer HTTP **402** with an [x402](https://www.x402.org/) payment envelope (asset, amount, payTo) when called without payment. Agents pay and retry; the MCP server wraps the same flow as tools. This makes "verify before you buy" a primitive an agent can execute end-to-end without a human.

The envelope's `network` is the CAIP-2 id of the chain the gateway is actually running on — `eip155:196` on mainnet, where settlement is in USD₮0 ([`0x779Ded…3736`](https://www.oklink.com/xlayer/address/0x779Ded0c9e1022225f8E0630b35a9b54bE713736)). The gateway **refuses to start** if that value disagrees with its own `CHAIN_ID`: advertising a chain you are not on would send a buyer's funds somewhere you cannot settle them, and that failure is silent.

Cachet is listed as an ASP on **[okx.ai/agents/7530](https://www.okx.ai/agents/7530)**, so an agent can discover it and pay for it without any prior relationship with us.

### The six MCP tools

| Tool | Endpoint | Price |
|---|---|---|
| `verify_originality` | `POST /v1/verify` | 0.02 USDT |
| `commit_work` | `POST /v1/commit` | 0.01 USDT |
| `register_and_mint` | `POST /v1/mint` | 0.5 USDT + 2% premium on-chain |
| `get_certificate` | `GET /v1/cert/:id` | free |
| `challenge_certificate` | `POST /v1/challenge` | on-chain bond |
| `watch_subscribe` | `POST /v1/watch` | 0.1 USDT / 30 days |

The MCP server never holds funds. It forwards to the gateway and passes the `402` straight back to the calling client, which is what signs the payment. Point it at the live gateway:

```json
{
  "mcpServers": {
    "cachet": {
      "command": "pnpm",
      "args": ["--dir", "apps/mcp-server", "start"],
      "env": { "GATEWAY_URL": "https://api.cachetprotocol.xyz" }
    }
  }
}
```

## Honest limitations

We sell trust, so the fine print is the product:

- **The registry is our corpus, not the internet.** "First-seen" means first seen by Cachet.
- **Coverage is capped, and the cap is small.** It is an on-chain parameter (`maxDeclaredValue`) that differs per deployment and is further bounded by the vault balance — see the table below, but read the contract to be sure. A claim can only ever pay what the vault actually holds.
- **Adjudication is centralized**, constrained by a public liveness window and published admissible-evidence rules ([`contracts/RESOLVER.md`](contracts/RESOLVER.md)). On mainnet the resolver is a 2-of-3 multisig, which removes the single-key failure mode but **not** the centralization: the operator still decides. Trustless adjudication it is not — the roadmap is a decentralized oracle set (3+ independent resolvers).
- **The embedding tier is advisory.** Only the deterministic perceptual-hash ensemble backs hard claims; there is no "AI detector" here.
- **Testnet collateral is not collateral.** The testnet vault holds `MockUSDT`, which has a public faucet. Only the mainnet deployment is backed by a token that costs anything to acquire.

## Security invariants (each one has a test)

`cd contracts && forge test` → **169 tests across 7 suites, 0 failed.** The five invariants below are the ones worth naming:

| Invariant | Proven in |
|---|---|
| Payout always goes to `ownerOf(certId)` at resolution, never to a parameter | [`contracts/test/Integration.t.sol`](contracts/test/Integration.t.sol) |
| No mint path except the gateway; no revoke/payout path except ChallengeManager | [`contracts/test/CachetRegistry.t.sol`](contracts/test/CachetRegistry.t.sol) |
| The vault never transfers more than its balance: partial payout + event, not a locking revert | [`contracts/test/CachetVault.t.sol`](contracts/test/CachetVault.t.sol) |
| Waiting period and coverage window are enforced on-chain, assessed when a challenge is **opened** | [`contracts/test/ChallengeManager.t.sol`](contracts/test/ChallengeManager.t.sol) |
| Challenger bonds are earmarked, never spendable as claim liquidity | [`contracts/test/CachetVault.t.sol`](contracts/test/CachetVault.t.sol) |

## Contracts

### X Layer mainnet (chain 196) — the collateralized deployment

| Contract | Address | Verified source |
|---|---|---|
| CachetRegistry | [`0x4A88…88D6`](https://www.oklink.com/xlayer/address/0x4A88e9B882C3109e8D786e5e075ccC004b5188D6) | [Sourcify](https://repo.sourcify.dev/196/0x4A88e9B882C3109e8D786e5e075ccC004b5188D6) |
| CachetCertificate | [`0xa372…4FEF`](https://www.oklink.com/xlayer/address/0xa372e0Ae92172928D7800F32542414fC595E4FEF) | [Sourcify](https://repo.sourcify.dev/196/0xa372e0Ae92172928D7800F32542414fC595E4FEF) |
| CachetVault | [`0x8989…a9f4`](https://www.oklink.com/xlayer/address/0x89893D5DDedAf7C6b04Cde7B9101e12F7Cc0a9f4) | [Sourcify](https://repo.sourcify.dev/196/0x89893D5DDedAf7C6b04Cde7B9101e12F7Cc0a9f4) |
| ChallengeManager | [`0xF3a2…65a7`](https://www.oklink.com/xlayer/address/0xF3a222E0f58B664ae356035290757dD3A5C765a7) | [Sourcify](https://repo.sourcify.dev/196/0xF3a222E0f58B664ae356035290757dD3A5C765a7) |
| USD₮0 (pay token, 6 decimals) | [`0x779D…3736`](https://www.oklink.com/xlayer/address/0x779Ded0c9e1022225f8E0630b35a9b54bE713736) | third-party token, not ours |

The pay token is the canonical USD₮0 on X Layer, **not** the older bridged USDT at `0x1e4a5963…d41d`. They are different tokens and do not interchange. Resolver: Safe 2-of-3 at [`0xE6b3…9268`](https://www.oklink.com/xlayer/address/0xE6b38687B18e75631086b9b39ca0406b6a0F9268) — set once at deploy and not changeable without redeploying the system.

### X Layer Testnet (chain 1952) — where the walkthrough above lives

| Contract | Address | Verified source |
|---|---|---|
| CachetRegistry | [`0x60BE…9069`](https://www.okx.com/web3/explorer/xlayer-test/address/0x60BEB9aAF8Bf6066A183F99702A403fAfaD19069) | [Sourcify](https://repo.sourcify.dev/1952/0x60BEB9aAF8Bf6066A183F99702A403fAfaD19069) |
| CachetCertificate | [`0xBB0a…7043`](https://www.okx.com/web3/explorer/xlayer-test/address/0xBB0a921b0C575114B6CbBD7c6E8529855B697043) | [Sourcify](https://repo.sourcify.dev/1952/0xBB0a921b0C575114B6CbBD7c6E8529855B697043) |
| CachetVault | [`0x79e9…8834`](https://www.okx.com/web3/explorer/xlayer-test/address/0x79e959A25aF30e01D0bc9e52C693D92e02C28834) | [Sourcify](https://repo.sourcify.dev/1952/0x79e959A25aF30e01D0bc9e52C693D92e02C28834) |
| ChallengeManager | [`0x8BF7…E664`](https://www.okx.com/web3/explorer/xlayer-test/address/0x8BF7551F7e9CB432EbA5fFC21972Bce7f509E664) | [Sourcify](https://repo.sourcify.dev/1952/0x8BF7551F7e9CB432EbA5fFC21972Bce7f509E664) |
| MockUSDT (pay token, 6 decimals) | [`0x9ad1…fa40`](https://www.okx.com/web3/explorer/xlayer-test/address/0x9ad14e783DCe270BE1214153E940aa686f91fa40) | [Sourcify](https://repo.sourcify.dev/1952/0x9ad14e783DCe270BE1214153E940aa686f91fa40) |

Parameters live on-chain and are readable by anyone — the table below is a convenience, the contract is the truth:

| Parameter | Mainnet (196) | Testnet (1952) |
|---|---|---|
| Coverage cap (`maxDeclaredValue`) | 2 USDT | 100 USDT |
| Fraud bond | 1 USDT | 5 USDT |
| Challenge bond | 1 USDT | 10 USDT |
| Premium | 2% | 2% |
| Waiting period / liveness window | 72 h / 48 h | 72 h / 48 h |

The mainnet numbers are smaller on purpose. The cap is set at or below what the vault actually holds, so the advertised guarantee is one the contract can pay in full. A larger cap over the same vault would not fail loudly — it would quietly become a `PartialPayout`, which is exactly the kind of number this project refuses to print.

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

## License

MIT. See [`LICENSE`](LICENSE).

## Team

Built by [**@scientivan**](https://github.com/scientivan) (off-chain brain: engine, gateway, watch) and [**@wngstnr-code**](https://github.com/wngstnr-code) (on-chain + proof page: contracts, cert page), pair-programming with two AI agents in one monorepo.
