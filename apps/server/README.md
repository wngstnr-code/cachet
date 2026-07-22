# @cachet/server — Gateway (A3)

Gateway off-chain Person A: REST §3.3 + Originality Profile §3.2 + signer EIP-712 +
`ChainClient`. Memanggil engine A1 (HTTP) dan chain (stub sekarang, viem di A5).

**PR-3 = REST core + stub chain.** x402 payment guard & MCP tools menyusul di PR-4.

Spec: `docs/technical_implementation_plan.md` §3.2/§3.3/§4-A3 · RFC-001 (P1/P4/P5/P6/P7)
· `packages/contracts-abi/README.md` (6 aturan gateway vs kontrak nyata).

## Jalankan

```bash
pnpm install
pnpm test           # 25 test (unit + stub + routes), tanpa jaringan/Python
pnpm typecheck

# Dev (butuh engine A1 berjalan di ENGINE_URL):
#   di services/engine: ENGINE_EMBEDDER=fake python -m app.main   (port 8100)
ENGINE_URL=http://localhost:8100 GATEWAY_PORT=8787 pnpm start
```

Env dari `.env` root (§8.1): `ENGINE_URL`, `GATEWAY_PORT`, `GATEWAY_PK` (signer;
ephemeral bila kosong — dev saja), `CHAIN_ID` (1952), `CERT_PAGE_BASE` (dari B, H4),
`DEMO_MODE`, `GATEWAY_DATA_DIR`.

## Endpoint (§3.3)

| Method | Guna |
|---|---|
| `POST /v1/verify` | Originality Profile §3.2 (tertandatangani EIP-712). `declared_value` opsional → `premium_quote`. |
| `POST /v1/commit` | submit commit-reveal (client kirim `commit_hash`, atau server hitung dari `phash0+salt+creator`). |
| `POST /v1/mint` | `register_and_mint` atomik → cert_id, cert_page_url, profil. Tolak `NEAR_DUP` (409). Menyemai registry. |
| `GET /v1/cert/:id` | CertData + status (ACTIVE/PENDING/EXPIRED/REVOKED/NOT_INSURABLE) + umur + challenges survived. |
| `POST /v1/challenge` | challenge_id + **instruksi approve ke VAULT** (RFC-001 P6). |
| `POST /v1/watch` | subscribe Watch → subscription_id (worker A4/PR-5 membacanya). |

Semua endpoint mutasi **idempotent** bila diberi `request_id` sama. Error seragam
`{ error: { code, message } }` — `code` mencerminkan nama error kontrak.

## Desain kunci

- **`ChainClient` interface** (`chain/types.ts`) — satu bentuk untuk `StubChainClient`
  (sekarang) & `ViemChainClient` (A5). Swap tak menyentuh routes.
- **Stub meniru aturan kontrak nyata**: `WrongPremium`/`WrongFraudBond`/
  `DeclaredValueTooHigh`, commit sekali-pakai & tolak overwrite, id mulai 1, satu
  gugatan terbuka per cert. Bug integrasi muncul di test, bukan saat rekaman.
- **Uang = string base-unit 6 desimal**; premi `declaredValue*bps/10000` BigInt floor,
  nilai pengikat dibaca dari `chain.quotePremium()` (jangan hardcode).
- **Status coverage** ditentukan chain (`isCoverageActive`), bukan jam gateway —
  jam gateway hanya membedakan PENDING vs EXPIRED.
- **DEMO_MODE** (§13): verify membalas fixture (`ORIGINAL`/`NEAR_DUP`) tanpa engine.
  Wajib 0 di deployment yang dilisting.

## Terverifikasi (22 Jul)

E2e nyata engine(Python) + gateway(TS) + stub: verify(ORIGINAL, premi 2%,
tertandatangani) → mint(cert_id 1) → get_cert(PENDING) → **mint ulang gambar sama →
NEAR_DUP 409** (mint pertama menyemai registry). 25 test unit/integrasi hijau.

## Belum di PR ini (menyusul)

- **PR-4:** x402 payment guard + MCP server (`apps/mcp-server`).
- **A5:** `ViemChainClient` (baca/tulis on-chain), swap dari stub; deploy publik.
