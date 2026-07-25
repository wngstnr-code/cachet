# be-plan.md — Rencana implementasi A1–A4 (pasangan dari be-tracker.md)

> Tracker (`be-tracker.md`) = APA yang harus dikerjakan + progress.
> File ini = BAGAIMANA mengerjakannya: urutan, keputusan tooling, layout file,
> strategi PR. Kalau ada konflik dengan spec, spec menang:
> `docs/technical_implementation_plan.md` §4 + `packages/contracts-abi/README.md`.

## Keputusan tooling (diambil 22 Jul, sesi #2 — berdasar cek mesin)

| Keputusan | Pilihan | Alasan |
|---|---|---|
| Python | **python3.13 + venv + pip `requirements.txt`** (BUKAN 3.14 default mesin) | torch/faiss-cpu wheel untuk 3.14 belum tentu ada; 3.13.14 terpasang & didukung. uv/poetry tidak terpasang — jangan tambah prasyarat |
| Vector index | **faiss-cpu (`IndexFlatIP`)**; fallback numpy matmul bila wheel 3.13 bermasalah | ≤100k entri 512-d: numpy inner-product setara — index internal A, bebas diganti selama §3.2 tetap |
| Node | **pnpm per-app, self-contained** (`apps/server`, `apps/mcp-server`, `services/watch` masing-masing punya `package.json`) | Root `pnpm-workspace.yaml` = edit zona bersama (butuh review B) — dihindari |
| Import ABI | `"@cachet/contracts-abi": "file:../../packages/contracts-abi"` | Tanpa workspace; `exports` package-nya sudah menunjuk `index.ts` (`as const` → inferensi viem penuh) |
| tsconfig | tiap app `extends: "../../tsconfig.base.json"` | Sudah disediakan di root |
| Arsitektur A3 | Logika di **`apps/server`** (Fastify REST); **`apps/mcp-server`** = wrapper tipis MCP tools → panggil REST gateway | Satu sumber logika; MCP hanya surface §3.3 |
| Storage bersama A | SQLite tunggal `data/cachet.db` (WAL): engine punya tabelnya sendiri; gateway tulis `subscriptions`; watch baca subs + tulis `last_checked_entry_id` | Semua folder A; hindari API tambahan antar service |
| Test | pytest (engine) · vitest (gateway/watch) | standar |
| Data/venv | `data/`, `.venv/`, `node_modules/` di-ignore via `.gitignore` LOKAL per folder A (bukan edit root `.gitignore`) | root = zona bersama |

## Urutan pengerjaan & PR (branch `feat/a-*`, PR kecil & sering)

Dependensi nyata: A2 butuh A1 (endpoint /hash /index) · A3 butuh A1 (verify memanggil engine) · A4 butuh A1+A3 (subs dari gateway, kueri ke engine). Jadi urutannya lurus:

### PR-1 `feat/a-engine-core` — A1 lengkap (target: H2 malam–H3 pagi)
`services/engine/`:
```
services/engine/
  app/main.py            # FastAPI, load_dotenv(find_dotenv()), ENGINE_PORT=8100
  app/hashing.py         # normalisasi (RGB, resize sisi panjang 512, strip alpha)
                         # + ensemble: phash, average_hash, dhash, whash @ hash_size=16 → 256 bit
  app/embedding.py       # open_clip ViT-B/32 CPU, 512-d L2-norm; embedding_commit = keccak(float32 bytes)
  app/store.py           # SQLite entries(entry_id, phash0..3 BLOB, sha256, source, uri, created_at) + FAISS
  app/verdict.py         # NEAR_DUP ≥2 hash Hamming ≤25 · GRAY_ZONE cosine 0.90–0.97 · ORIGINAL
                         # distinctiveness = 1 − max cosine; label 0.7/0.3
  app/c2pa.py            # c2pa-python; fallback deteksi JUMBF box → c2pa_present saja
  app/routes.py          # POST /hash · POST /index · POST /query (+ GET /healthz)
  tests/                 # ≥10 kasus §4-A1.7 (fixture gambar digenerate Pillow, bukan aset besar di git)
  requirements.txt  README.md  .gitignore
```
Catatan: kueri pHash = linear scan Hamming numpy (XOR+popcount), bukan FAISS — FAISS hanya untuk embedding.
**Acceptance (gate):** `pytest` hijau; `/query` dgn versi resize dari gambar ter-index → NEAR_DUP min_hamming ≤25.

### PR-2 `feat/a-preseed` — A2 (target: H3 siang)
`scripts/preseed.py` + `scripts/demo_fixtures.py`:
- Ingest ≥5.000 gambar publik (koleksi NFT via API publik/IPFS + subset Wikimedia Commons) → panggil engine `/hash`+`/index`; simpan HANYA hash+embedding+URI. Checkpoint & resume (rate-limit friendly); fallback jujur ≥1k.
- Fixture "the catch": 3–5 karya korban + salinan modifikasi (resize/crop/recolor) di `scripts/demo/` → assert semua tertangkap NEAR_DUP.
- Tulis `scripts/corpus-coverage.md` (jumlah + sumber) untuk disclosure.
**Acceptance:** ≥5k entri; semua fixture tertangkap; kueri <2 dtk.

### PR-3 `feat/a-gateway-core` — A3 tanpa x402 dulu (target: H3)
`apps/server/`:
```
apps/server/src/
  index.ts               # Fastify; dotenv path ../../.env; rate limit; max upload 10 MB
  routes/                # §3.3: verify, commit, mint, cert, challenge, watch  (+ error {error:{code,message}})
  profile.ts             # builder Originality Profile PERSIS §3.2 (uang string base-unit + _display)
  signer.ts              # EIP-712 domain Cachet-v1, Verdict(...phashesHash...); phashesHash=keccak(concat 4 hash)
  premium.ts             # (declaredValue * 200n) / 10000n — BigInt floor + unit test nilai ganjil 33333333
  commit.ts              # helper rumus keccak(abi.encodePacked(phash0, salt, creator)) + contoh di response
  chain/ChainClient.ts   # interface: registerAndMint(MintRequest)→{entryId,certId} · commit · challenge
                         #            getCertificate (certData+isCoverageActive+ownerOf) · params (fraudBond, quotePremium)
  chain/StubChainClient.ts  # in-memory, state konsisten, meniru aturan kontrak NYATA:
                         #   commit sekali-pakai & tolak overwrite · WrongPremium/WrongFraudBond ·
                         #   declaredValue ≤ maxDeclaredValue · id mulai 1 · waitingPeriod/coverage window
  engine.ts              # klien HTTP ke ENGINE_URL
  idempotency.ts  db.ts  # request_id dedup; better-sqlite3 → data/cachet.db (tabel subscriptions dll.)
  fixtures/              # DEMO_MODE=1: profile ORIGINAL, NEAR_DUP "the catch", CertData contoh (konsisten §3.2)
```
Alur mint (§4-A3.4): verify internal → tolak NEAR_DUP → insurable=false bila GRAY_ZONE → premi BigInt → satu panggilan `registerAndMint`. Response challenge WAJIB instruksi approve ke **VAULT** (P6). Status cert: REVOKED / NOT INSURABLE / PENDING / EXPIRED / ACTIVE.
**Acceptance:** e2e lokal engine+gateway+stub: verify → mint → get_certificate.

### PR-4 `feat/a-mcp-x402` — sisa A3 (target: H3 malam, JANGAN geser ke H5)
- `apps/mcp-server/`: `@modelcontextprotocol/sdk`, expose 6 tools §3.3 → forward ke REST gateway.
- x402 middleware di `apps/server` (OKX Payment SDK; konsultasi skill `okx-agent-payments-protocol`): endpoint berbayar balas 402 + payment requirements, verifikasi settlement sebelum eksekusi; `X402_BYPASS=1` hanya dev. Buntu total → jalur darurat §12: listing gratis dulu (eskalasi ke Dien).
**Acceptance (gate H3):** tanpa bayar → 402; e2e stub tetap hijau lewat MCP client.

### PR-5 `feat/a-watch` — A4 (target: H4)
`services/watch/`: node-cron (`CRON_SCHEDULE` 6 jam) + trigger manual (CLI/HTTP kecil) → per subscription: kueri engine utk entri > `last_checked_entry_id` yang NEAR_DUP vs aset diawasi → webhook alert + draft challenge (evidence = entri lama + timestamp) ke `data/` dashboard-lite → update state.
**Acceptance:** subscribe X, register X′ → alert <1 siklus. *Potong-scope: tombol "re-scan now" manual.*

## Verifikasi akhir fase (sebelum masuk A5)
1. `pytest` + `vitest` hijau semua.
2. Skrip e2e stub: verify(gambar baru)=ORIGINAL → verify(fixture)=NEAR_DUP → commit → mint(reveal) → get_certificate(PENDING→ACTIVE via waktu stub) → challenge(instruksi vault) → watch alert.
3. `X402_BYPASS=0` → semua endpoint berbayar balas 402.
4. Profile JSON divalidasi terhadap §3.2 (test snapshot schema).

## Sesi #9 (22 Jul) — resume deploy M5 + verifikasi protokol A5.4

Codex sesi sebelumnya berhenti tepat sebelum `cachetctl backup` karena kena
**limit usage Codex sendiri** (bukan blocker VPS/akses nyata — SSH dari sesi
lain berjalan normal). Yang dieksekusi untuk menuntaskan:

1. **Deploy M5 ke VPS** (`ssh ubuntu@15.235.146.33`, `sudo /opt/cachet/cachetctl ...`):
   - Cek dulu `deploy.env` (masih SHA lama `081f8f6…`) vs `.env` (credential OKX
     **sudah terisi** dari sesi sebelumnya — langkah `sudoedit` sudah beres,
     tak perlu diulang).
   - `sed -i` bump `ENGINE_IMAGE`/`GATEWAY_IMAGE` di `/opt/cachet/deploy.env` ke
     `sha-84c5ea2bb6843410c77e0cd89c75ffd4a2498dc5` (SHA merge PR #30).
   - `cachetctl deploy` → backup, pull, rolling update engine (corpus 5000 ✅)
     lalu gateway, smoke internal ✅. Smoke publik sempat 503 sesaat (race
     restart container vs Caddy/Cloudflare) — hilang sendiri dalam detik,
     `cachetctl smoke` re-run 100% hijau.

2. **Verifikasi A5.4 (buyer-side x402)** — dibuat
   `apps/server/scripts/x402-buyer-smoke.mts`: pembeli OKX-compatible pakai
   `@okxweb3/x402-evm` (`toClientEvmSigner`, `registerExactEvmScheme`) +
   `@okxweb3/x402-core/client` (`x402Client`, `x402HTTPClient`). Alur:
   POST tanpa bayar → decode header `payment-required` (base64 JSON) →
   `createPaymentPayload` (signing EIP-3009 `TransferWithAuthorization`) →
   retry dengan header signature → cek 200 + `payment-response`.
   - **Bug ketemu & fix:** signer awal pakai viem `createWalletClient(...).extend(publicActions)`
     langsung — SDK OKX butuh field `.address` di top-level objek signer
     (`ClientEvmSigner`), tapi WalletClient viem taruh address di `.account.address`.
     Fix: pakai helper resmi `toClientEvmSigner(account, publicClient)` dari
     `@okxweb3/x402-evm`.
   - **Hasil terhadap production nyata** (`https://api.cachetprotocol.xyz/v1/verify`):
     402 challenge asli diterima — `scheme=exact`, `network=eip155:1952`,
     `amount=20000` (=$0.02), `asset=0x9e29b3aada05bf2d2c827af80bd28dc0b9b4fb0c`
     (USD₮0), `payTo=0xa3C3f8eE84a301fc4BD63DD712344d627230514B`. Signing &
     retry berhasil sempurna. Gagal HANYA di settlement on-chain OKX Broker:
     `{"error":"payment settlement failed"}` — sebab `DEMO_CREATOR_ADDR`
     (`0x8ca39bDb97b5C6b75425c0E494a886E57A937f7a`) punya OKB cukup tapi
     **USD₮0 saldo = 0** (dicek via `eth_call balanceOf` langsung, bukan asumsi).
   - **Kesimpulan:** seluruh pipeline x402 v2 (server config, SDK Fastify,
     Broker auth, EIP-3009 signing) terbukti benar end-to-end. Satu-satunya sisa
     hambatan A5.4 adalah **dana**, bukan kode/deploy.

3. **✅ TUNTAS (lanjutan sesi #9, setelah Dien top-up 10 USD₮0 ke `DEMO_CREATOR_ADDR`):**
   - Konfirmasi dulu `balanceOf` on-chain sebelum percaya faucet (sempat ada
     kesalahan: address pertama yang dicek Dien ternyata *faucet dispenser
     contract*, bukan token — `name()`/`symbol()` revert, bukan ERC20).
   - Refactor kecil skrip: terima `ROUTE` + `BODY` (JSON) via env supaya bisa
     dipakai untuk endpoint lain tanpa duplikasi skrip.
   - Paid `/v1/verify` → 200, settlement sukses.
   - Paid `/v1/mint` (gambar unik via PIL biar verdict `ORIGINAL` bukan
     `NEAR_DUP`, `declared_value=50000000`) → 200, **cert #15 nyata**
     (`tx_hash` mint + `tx` settlement Broker terpisah, keduanya sukses),
     dikonfirmasi publik lewat `GET /v1/cert/15` (`status=ACTIVE`).
   - **A5.4 closed.** Golden Path x402 sungguhan (bukan simulasi) terbukti
     dari verify sampai mint dengan pembeli eksternal nyata.

   Command yang dipakai (referensi untuk run lain, mis. sebelum listing D3):
   ```bash
   cd apps/server
   # verify
   BUYER_PK=<DEMO_CREATOR_PK> pnpm exec tsx scripts/x402-buyer-smoke.mts
   # mint (declared_value/creator_address/image_b64 sesuai kebutuhan)
   ROUTE=/v1/mint BODY='{"creator_address":"0x...","declared_value":"50000000","image_b64":"<png unik>"}' \
     BUYER_PK=<DEMO_CREATOR_PK> pnpm exec tsx scripts/x402-buyer-smoke.mts
   ```

**Catatan kecil, bukan blocker:** `/opt/cachet/cachetctl` di VPS masih membawa
satu warning basi (`X402_FACILITATOR_URL is empty`) dari sebelum migrasi M5 —
tidak ada di `scripts/deploy/cachetctl.sh` versi repo. Operator script di VPS
tidak auto-sync dari repo (memang tidak ada CI/CD aktif); re-install manual
kapan-kapan cukup, tidak mendesak.

**File baru `apps/server/scripts/x402-buyer-smoke.mts` belum di-commit** — folder
A, aman untuk masuk PR kapan pun Dien minta (mis. sekalian dengan PR follow-up
D9/A5.4).

## Risiko yang sudah diantisipasi
- **torch/open_clip di 3.13 gagal wheel** → coba `pip install open_clip_torch torch --index-url pypi` dulu di awal PR-1; gagal → turunkan ke 3.12 via brew (keputusan saat itu, catat di tracker).
- **Model CLIP unduhan pertama lambat** → cache di `data/models/`; preseed embedding precompute offline (§12).
- **x402 SDK macet** → dikerjakan H3 (PR-4) bukan H5; jalur darurat listing gratis.
- **Preseed rate-limit** → checkpoint/resume + fallback ≥1k jujur.
- **API §3.3 menyebut URL cert page** → sebelum `CERT_PAGE_BASE` ada (H4, dari B): isi placeholder dari env, jangan hardcode.
