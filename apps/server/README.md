# @cachet/server — Gateway (A3)

Gateway off-chain Person A: REST §3.3 + Originality Profile §3.2 + signer EIP-712 +
`ChainClient` + payment gate x402 v2 resmi OKX. Memanggil engine A1 (HTTP), OKX
Payment Broker, dan chain (stub untuk test; viem pada deployment testnet).

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
ephemeral bila kosong — dev saja), `CHAIN_ID` (1952), `CERT_PAGE_BASE`,
`DEMO_MODE`, `GATEWAY_DATA_DIR`, dan konfigurasi x402 pada bagian berikut.

## x402 v2 / OKX Payment SDK

Empat endpoint berbayar (`verify`, `commit`, `mint`, `watch`) dilindungi
`@okxweb3/x402-fastify`. Request tanpa bayar menerima `402` +
`PAYMENT-REQUIRED`; buyer retry memakai `PAYMENT-SIGNATURE`; settlement sukses
menghasilkan `PAYMENT-RESPONSE`. SDK memverifikasi sebelum handler dan settle
setelah handler menghasilkan respons sukses. Respons bisnis 4xx/5xx tidak di-settle.

Deployment hackathon dikunci ke `X402_NETWORK=eip155:1952`. SDK memakai USD₮0
testnet resmi, bukan `ADDR_MOCKUSDT`. Env produksi: `X402_PAY_TO`,
`X402_RESOURCE_BASE`, `OKX_BASE_URL`, `OKX_API_KEY`, `OKX_SECRET_KEY`, dan
`OKX_PASSPHRASE`. `X402_BYPASS=1` hanya untuk dev/test; saat bernilai `0`, gateway
menolak start jika credential tidak lengkap atau URL publik/Broker bukan HTTPS.

## Endpoint (§3.3)

| Method | Guna |
|---|---|
| `POST /v1/verify` | Originality Profile §3.2 (tertandatangani EIP-712). `declared_value` opsional → `premium_quote`. |
| `GET /v1/verify` | Sama, lewat query `image_url` (+ `declared_value`, `request_id`). Read-only. `image_b64` tetap POST-saja. |
| `POST /v1/commit` | submit commit-reveal (client kirim `commit_hash`, atau server hitung dari `phash0+salt+creator`). |
| `POST /v1/mint` | `register_and_mint` atomik → cert_id, cert_page_url, profil. Tolak `NEAR_DUP` (409). Menyemai registry. |
| `GET /v1/cert/:id` | CertData + status (ACTIVE/PENDING/EXPIRED/REVOKED/NOT_INSURABLE) + umur + challenges survived. |
| `POST /v1/challenge` | challenge_id + **instruksi approve ke VAULT** (RFC-001 P6). |
| `POST /v1/watch` | subscribe Watch → subscription_id (worker A4/PR-5 membacanya). |

Semua endpoint mutasi **idempotent** bila diberi `request_id` sama. Error seragam
`{ error: { code, message } }` — `code` mencerminkan nama error kontrak.

### Method di endpoint berbayar

Keempat path berbayar (`/v1/verify`, `/v1/commit`, `/v1/mint`, `/v1/watch`) membalas
**402 untuk method apa pun**, bukan hanya POST. Ini bukan kerapian — validator listing
OKX memprobe endpoint dengan GET, dan gate yang hanya menutup POST membuat GET jatuh ke
404 sehingga layanannya dinilai bukan x402 sama sekali. Lihat catatan di
`src/x402/prices.ts`.

Sesudah pembayaran, `commit`/`mint`/`watch` membalas **405 + `Allow: POST`** untuk GET:
ketiganya menulis ke chain, dan GET harus aman diulang (cache/prefetch/crawler bisa
memicunya kembali). SDK tidak melakukan settlement pada respons ≥400, jadi pemanggil
yang salah method tidak kehilangan uang.

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

## Chain mode: stub vs viem (A5)

`ChainClient` punya dua implementasi, dipilih `CHAIN_MODE` (auto = `viem` bila
`ADDR_CERTIFICATE` terisi non-nol, selain itu `stub`):

- **`stub`** (`chain/stub.ts`) — in-memory, meniru aturan kontrak. Untuk test & dev.
- **`viem`** (`chain/viem.ts`) — on-chain nyata via viem. Baca param dari chain
  (`quotePremium`/`fraudBondAmount`/`waitingPeriod`), `registerAndMint` atomik,
  `certData`/`isCoverageActive`/`ownerOf`, `challenge`. `ensureReady()` approve
  payToken ke Vault sekali (maxUint256) saat start.

Env viem: `CHAIN_MODE=viem`, `RPC_URL`, `CHAIN_ID`, `GATEWAY_PK`, `ADDR_REGISTRY`/
`ADDR_CERTIFICATE`/`ADDR_VAULT`/`ADDR_CHALLENGE`/`ADDR_MOCKUSDT` (isi H3 dari B).

### Rehearsal integrasi lokal (tanpa testnet)

`scripts/local-anvil-e2e.sh` mendeploy kontrak B ke anvil lokal (chain-id 1952) dan
menjalankan gateway `CHAIN_MODE=viem` terhadapnya — menutup celah E3 sebelum H5.

**Terverifikasi (22 Jul):** verify (premi dari chain) → `registerAndMint` on-chain
(cert nyata, `certCount=1`, `ownerOf`=creator) → get_cert PENDING → tunggu waiting
period → **ACTIVE** (isCoverageActive on-chain) → challenge buka gugatan. 34 test
unit (stub) tetap hijau.

## Operasi yang masih terpisah

- Paid smoke test publik X Layer Testnet (A5.4), registrasi ASP OKX.AI, dan
  post-listing marketplace acceptance dilakukan setelah image gateway ini lolos
  test lokal dan dideploy.
