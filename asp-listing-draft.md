# ASP Listing Draft — okx.ai (M3, for D3)

> Local working file, NOT committed (same rule as be-tracker.md / be-plan.md).
> Copy-paste per field into the okx.ai ASP registration form (Agentic Wallet Dien).
> Every claim below follows the honest-language rules (claude.md §7): no
> "insurance", no "100% original", no "AI detector", no "trustless".

---

## 1. Name — brand name (form rule: 3–25 EN chars; no test markers / celebrity names)

```
Cachet
```

(6 chars ✓. Alternatif kalau "Cachet" ditolak karena terlalu generik/bentrok:
`Cachet Protocol` — 15 chars ✓, cocok dengan domain cachetprotocol.xyz.)

## 2. Description — one-sentence summary (form rule: required, ≤500 chars)

Primary (358 chars, satu kalimat):

```
Cachet lets AI agents and creators check a digital work against its first-seen registry and mint a collateral-backed, transferable ERC-721 certificate — paid per call via x402 on X Layer Testnet — so that if the work is later proven to be a copy, the on-chain vault pays whoever holds the certificate at that moment, not the creator who made the false claim.
```

Alternatif (374 chars) bila mau menonjolkan timestamp + bond:

```
Cachet issues first-seen certificates for digital work that put money behind their claim: a work is recorded in the Cachet registry at a verifiable on-chain timestamp, backed by a fraud bond and premium in an on-chain vault, and if it is later proven to be a copy the vault pays the current certificate holder — all callable by AI agents per x402 payment on X Layer Testnet.
```

## Tagline (BUKAN field form — untuk X post / README / materi lain)

```
Collateralized First-Seen Certificates for Digital Work
```

(55 chars — tidak muat di field Name (max 25), memang bukan untuk situ.)

## Long description

```
"Certificates of authenticity" are usually just words: when one turns out to be
wrong, nobody pays. Cachet is different in two ways.

First-seen, not "original". The registry records when a work was first seen by
Cachet, with a timestamp anyone can verify on X Layer. We never claim to know
the whole internet — the claim is precise and checkable.

Collateralized. Minting a certificate requires a fraud bond and a premium paid
into an on-chain vault. The certificate is a transferable ERC-721: sell the
work, transfer the NFT, and the guarantee moves with it. At resolution the
vault pays ownerOf(certId) — never a hardcoded creator address.

The Golden Path, all on-chain:
1. verify — the engine checks the work against the registry (perceptual-hash
   ensemble; the embedding tier is advisory only) and returns a signed
   Originality Profile.
2. certify — pay the premium + fraud bond, mint the certificate NFT.
3. sell — the buyer receives the work and the certificate; coverage follows
   the holder.
4. challenge — anyone can dispute with evidence and a bond. A resolver rules
   after a public liveness window: upheld = certificate revoked and the vault
   pays the current holder; dismissed = the challenger's bond is slashed.

Built for AI agents: every paid endpoint speaks x402 v2 (OKX Payment Broker,
X Layer Testnet, USD₮0 settlement), so an agent can verify-before-buy and
certify end-to-end without a human. MCP tools wrap the same API.
```

## Service endpoint (A2MCP listing target)

```
https://api.cachetprotocol.xyz
```

- Type: HTTP REST resource server (x402 v2 seller). The MCP server is a thin
  local adapter over this same API — the listing target is the REST endpoint.
- Payment: x402 v2, scheme `exact`, network `eip155:1952` (X Layer Testnet),
  settlement asset USD₮0 (selected by the OKX Broker), payTo = Cachet gateway.
- Unpaid calls receive HTTP 402 with a base64 `PAYMENT-REQUIRED` challenge;
  retry with `PAYMENT-SIGNATURE` after signing (EIP-3009).

## Endpoints & pricing

| Endpoint | Price (x402) | What it does |
|---|---|---|
| `POST /v1/verify` | $0.02 | Check an image against the Cachet registry → signed Originality Profile (first-seen verdict; distinctiveness is advisory) |
| `POST /v1/commit` | $0.01 | Lock a commit-reveal hash BEFORE publishing (anti registry-sniping) |
| `POST /v1/mint` | $0.50 + 2% on-chain premium (separate tx) | Register first-seen + mint the collateral-backed certificate NFT |
| `POST /v1/watch` | $0.10 / 30 days | Subscribe to monitoring: new near-duplicates in the registry trigger an alert |
| `GET /v1/cert/:id` | Free | Certificate data + live coverage status (ACTIVE / PENDING / EXPIRED / REVOKED / NOT_INSURABLE) |
| `POST /v1/challenge` | Free (on-chain bond required) | Instructions to dispute a certificate: bond approval to the vault + evidence steps |
| `GET /healthz` | Free | Health check |

## Capabilities (MCP tool names, same API)

```
verify_originality  — image check against the registry → Originality Profile ($0.02)
commit_work         — commit-reveal lock before going public ($0.01)
register_and_mint   — first-seen record + collateral-backed ERC-721 ($0.50 + 2% premium)
get_certificate     — certificate + coverage status, free
challenge_certificate — dispute flow: bond instructions + evidence, free to query
watch_subscribe     — 30-day registry monitoring with alerts ($0.10)
```

## Disclosure / limitations (include verbatim or linked)

```
We sell trust, so the fine print is the product:

- The registry is our corpus, not the internet. "First-seen" means first seen
  by Cachet at an on-chain timestamp — it is not a claim of global originality.
- Coverage is capped at 2 USDT per certificate during bootstrap, and is further
  bounded by the vault balance. This is a deliberately small, fully funded cap:
  a claim can only ever pay what the vault actually holds, so we advertise the
  funded number rather than an aspirational one. The cap is an on-chain
  parameter — read it from the contract, do not trust this document.
- Adjudication is centralized. Rulings are executed by a 2-of-3 multisig held by
  the Cachet operator, constrained by a public liveness window and published
  admissible-evidence rules. The multisig removes the single-key failure mode;
  it does NOT make adjudication trustless or decentralized — the operator still
  decides. The roadmap is a decentralized oracle set (3+ independent resolvers).
- The embedding tier is advisory. Only the deterministic perceptual-hash
  ensemble backs hard claims.
- Runs on X Layer mainnet (chain 196); x402 payments settle in USD₮0.
```

## Links

| What | URL |
|---|---|
| API (listing target) | https://api.cachetprotocol.xyz |
| Certificate page (no backend, reads chain directly) | https://cachetprotocol.vercel.app |
| Live example cert (paid x402 mint) | https://cachetprotocol.vercel.app/cert/15 |
| Repo | https://github.com/wngstnr-code/cachet |
| Mint tx of cert #15 (explorer) | https://www.okx.com/web3/explorer/xlayer-test/tx/0x564ccc5e75d4232021a7624e9d61e4e749b7be55c36770c94d0bd35b8da57c78 |

## Category / tags (pick whatever the form offers)

```
Content provenance · Digital art · Certificates · x402 · Verification ·
Creator tools · NFT
```

## Contact / operator

```
Operator: Cachet team (Dien — off-chain gateway/engine; Wangsit — contracts/cert page)
Chain: X Layer Testnet (eip155:1952)
```
