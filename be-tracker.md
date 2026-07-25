# be-tracker.md — Tracker tugas PERSON A (Dien, "Off-chain Brain")

> **Untuk AI agent di sesi baru:** baca file ini PERTAMA. Ini satu-satunya sumber
> kebenaran untuk *progress* workstream A. Setelah mengerjakan apa pun:
> (1) centang/perbarui checkbox terkait, (2) perbarui blok **STATUS SEKARANG**,
> (3) tambah satu baris di **LOG SESI** paling bawah. Jangan hapus riwayat.
>
> **Rencana implementasi A1–A4 (urutan, tooling, layout file, strategi PR): `be-plan.md`.**
>
> Spec yang mengikat (jangan diduplikasi ke sini, baca langsung):
>
> - `CLAUDE.md` — aturan kolaborasi 2-agent (LARANGAN menulis folder B!)
> - `docs/technical_implementation_plan.md` — §1.3 parameter, §3 interface freeze (BEKU), §4 task A, §8 env
> - `docs/rfc-001-interface-freeze-fixes.md` — 8 keputusan yang mengubah §3 (semua DITERIMA)
> - `packages/contracts-abi/README.md` — 6 aturan wajib gateway vs kontrak nyata + tabel error
> - `docs/contract-gaps.md` — gap kontrak B; ada action item untuk Dien
> - `docs/delivery_implementation_plan.md` — listing ASP, video, README (fase H5–H7)

---

## ATURAN KERAS (berlaku setiap sesi)

1. **Hanya tulis di folder A:** `services/engine/`, `services/watch/`, `apps/server/`,
   `apps/mcp-server/`, `scripts/`. Folder B (`contracts/`, `apps/web/`, `packages/contracts-abi/`) = baca boleh, tulis TIDAK PERNAH.
2. Branch `feat/a-*`, semua lewat PR, tidak ada commit langsung ke `main`.
3. Uang = string base-unit 6 desimal; premi = `declaredValue * 200n / 10000n` (BigInt, floor).
4. Bahasa jujur: "guarantee/collateralized certificate" (bukan "insurance"),
first-seen di registry" (bukan "original/asli"), tier embedding = "advisory".
5. Jangan hardcode address/RPC/parameter kontrak — semua via `.env` / baca dari chain.
6. `X402_BYPASS` dan `DEMO_MODE` wajib `0` di deployment yang dilisting.

## KONSTANTA CEPAT (verifikasi ke §1.3 bila ragu)


| Hal             | Nilai                                                                                                                                                             |
| --------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Chain           | X Layer Testnet, chainId **1952**, RPC `https://testrpc.xlayer.tech`, gas OKB testnet                                                                             |
| MockUSDT (live) | `0x9ad14e783DCe270BE1214153E940aa686f91fa40` — 6 desimal, faucet `mint(address,uint256)` publik                                                                   |
| Verdict         | `NEAR_DUP` bila ≥2 dari 4 pHash Hamming ≤25 (256-bit); `GRAY_ZONE` bila max cosine 0.90–0.97; sisanya `ORIGINAL`                                                  |
| Ensemble        | imagehash `phash`, `average_hash`, `dhash`, `whash` — 16×16 → 256 bit; normalisasi: RGB, resize sisi panjang 512, strip alpha                                     |
| Embedding       | open_clip ViT-B/32, 512-d L2-normalized; `embedding_commit = keccak256(float32 bytes)`                                                                            |
| EIP-712         | domain `Cachet-v1`; `Verdict(bytes32 assetSha256,uint8 verdict,bytes32 phashesHash,uint64 timestamp)`; `phashesHash = keccak256(abi.encodePacked(phashes[0..3]))` |
| Rumus commit    | `keccak256(abi.encodePacked(bytes32 phash0, bytes32 salt, address creator))` — commit sekali-pakai on-chain                                                       |
| Harga x402      | verify 0.02 · commit 0.01 · mint 0.5 + premi 2% · watch 0.1/30 hari · get_* gratis                                                                                |
| Deadline        | submit **27 Jul 22:59 UTC**; target ASP live 25 Jul; H1 = 21 Jul                                                                                                  |


---

## STATUS SEKARANG (perbarui tiap sesi)

**Per: 2026-07-22 (H2) — A1–A5.3 SELESAI. Engine+gateway live di OVH shared VPS pada `https://api.cachetprotocol.xyz`.**

- **PR-1** `feat/a-engine-core`: engine A1, 33 test.
- **PR-2** `feat/a-preseed`: preseed+demo A2, 7 test. (base = PR-1)
- **PR-3** `feat/a-gateway-core`: gateway core A3, 25 test. (base = PR-1)
- **PR-4** `feat/a-mcp-x402`: x402 + MCP, 37 test. (base = PR-3)
- **PR-5** `feat/a-watch`: Watch A4, 34+4 test + e2e. (base = PR-4)
- **PR-6** `feat/a-integration`: A5 ViemChainClient + rehearsal anvil. (base = PR-5)

⚠️ **WORKFLOW STACKED-PR LINEAR** (PR-1 belum merge ke main):
`main → PR-1 → {PR-2}  &  PR-1 → PR-3 → PR-4 → PR-5 → PR-6`.
Base saat buka PR: PR-2 & PR-3 = `feat/a-engine-core`; PR-4 = `feat/a-gateway-core`;
PR-5 = `feat/a-mcp-x402`; **PR-6 = `feat/a-watch`**. Merge urut PR-1→3→4→5→6.
Jangan branch dari main mentah — engine belum di main.

Semua branch di `origin` (pull/new/`<branch>` untuk buka PR).

**UPDATE (22 Jul, sesi #3):** Wangsit **sudah deploy 4 kontrak ke X Layer testnet**
(main kini `162c29b`) + **tutup semua gap kode G1–G5** (rekomendasi review-ku diikuti).
`.env` Dien sudah terisi alamat kontrak asli. Cek on-chain: keempat kontrak LIVE,
`Certificate.gateway()` == `GATEWAY_ADDR` Dien (✅ boleh mint), wallet gateway punya
**0.2 OKB + 776 MockUSDT** (cukup), `waitingPeriod`=10s (mode demo). **Jadi integrasi
testnet SIAP dijalankan — tinggal tembak.** (⚠️ `addresses.testnet.json` masih ketulis
`PENDING_DEPLOY` — file serah-terima B belum di-update, tapi `.env` A sudah benar.)

**✅ MERGE KE MAIN SELESAI (sesi #3):** PR **#18** (`feat/a-integration`) + PR **#19**
(`feat/a-preseed`) sudah **MERGED** ke `origin/main` (kini `3d94c95`). Seluruh folder A
ada di main (engine/watch/server/mcp-server/scripts). `gh` login sebagai scientivan.
Catatan: local main pointer masih lama — Dien perlu handle perubahan uncommitted
sendiri (`.gitignore` + hapus `docs/cachet_idea_brief_v1.md`) lalu `git pull`.

**UPDATE deploy OVH (22 Jul):** branch `feat/a-ovh-deploy` menyiapkan image
`linux/amd64` non-root, Compose dengan limit resource, persistent state, backup/
rollback, Caddy Cloudflare Origin TLS, serta runbook shared VPS 2-vCore/4-GB.
SimpleArt tetap prioritas: Cachet di-pause saat deploy SimpleArt; deploy Cachet tidak
mematikan SimpleArt. **CLIP sengaja tidak dipasang** (`ENGINE_EMBEDDER=fake`). Jika
CLIP nanti diaktifkan, upgrade minimum yang direncanakan adalah 4-vCore/8-GB atau
pisahkan Cachet ke host lain.

**✅ D2 LIVE (22 Jul):** Cloudflare DNS + Full (strict) + Origin CA aktif;
engine/gateway image berjalan healthy non-root. Corpus persistent 5.000 entry;
public health=200, unpaid verify=402, cert #6=200. SimpleArt tetap healthy
selama cutover. Engine tidak mem-publish host port; gateway hanya
`127.0.0.1:8787`. `CERT_PAGE_BASE` production kini `https://cachetprotocol.vercel.app`
(domain baru per 23 Jul, sesi #13; sebelumnya cachet-six.vercel.app) dan cert
#6/#15 terbuka publik.

**✅ M5 DIDEPLOY (22 Jul, sesi #9):** VPS sekarang menjalankan image
`sha-84c5ea2bb6843410c77e0cd89c75ffd4a2498dc5` (merge PR #30, OKX x402 v2) untuk
engine+gateway. `cachetctl deploy` dijalankan penuh: backup state, pull image,
rolling update engine (corpus 5000 terverifikasi) lalu gateway, smoke internal+
publik hijau (health 200, unpaid verify 402, cert #6 200). `.env` VPS sudah
berisi credential OKX (`OKX_API_KEY`/`OKX_SECRET_KEY`/`OKX_PASSPHRASE`/
`OKX_BASE_URL`) — langkah `sudoedit` yang diminta sesi sebelumnya sudah beres.
Catatan kecil: `/opt/cachet/cachetctl` di VPS masih print warning basi
`X402_FACILITATOR_URL is empty` (sisa versi lama, harmless, tidak ada di skrip
repo) — bukan blocker, bisa dibersihkan lain kali install ulang script.

**✅ A5.4 SELESAI PENUH (sesi #9, setelah top-up Dien):** Dien isi 10 USD₮0
(faucet X Layer testnet, contract token dikonfirmasi cocok
`0x9e29b3aada05bf2d2c827af80bd28dc0b9b4fb0c`) ke `DEMO_CREATOR_ADDR`. Dengan
`apps/server/scripts/x402-buyer-smoke.mts` (buyer OKX-compatible resmi):

- **Paid `/v1/verify`:** 402→sign EIP-3009→retry→**200**, profile sah, settlement
Broker sukses (tx `0x4aa74b249dffe0809b7d3b183d088a045899ef1d30f0b7e5056dc4c5e2a1b5c0`).
- **Paid `/v1/mint`** (gambar unik baru, declared_value 50 USDT): 402→pay→**200**,
`verdict=ORIGINAL, insurable=true`, **cert #15 nyata di X Layer testnet**
(`tx_hash=0x564ccc5e75d4232021a7624e9d61e4e749b7be55c36770c94d0bd35b8da57c78`),
settlement Broker sukses (tx `0xa3936e0777387606bb830dfd841c6afe007a2293c70d5a14032bc8cbd6bf1d45`).
Dicek publik: `GET /v1/cert/15` → `status=ACTIVE`, `owner=DEMO_CREATOR_ADDR`,
coverage aktif. Cert page: `https://cachet-six.vercel.app/cert/15`.

**Golden Path x402 sungguhan (verify→mint→coverage) TERBUKTI end-to-end lewat
pembeli eksternal nyata, bukan simulasi/DEMO_MODE.** Sisa A5 tinggal D3 (ASP
okx.ai) + acceptance MCP eksternal (opsional, REST sudah cukup buktikan mekanisme).

**⏸ CI/CD BELUM SELESAI, SENGAJA DIPAUSE:** implementasi + seluruh check PR #28
sudah hijau, tetapi PR belum direview/merge; Environment `ovh-production`, deploy
key, variables, dua PAT GHCR, dan dispatch production pertama belum dikerjakan.
Lanjutkan hanya saat Dien meminta sesi CI/CD berikutnya.

**Next action A (selain CI/CD):** A5.4 dan D6 sudah tuntas. Fokus sekarang: daftar
ASP di okx.ai (D3, akun Dien) — satu-satunya blocker A5 tersisa — lalu ulangi Golden
Path yang sama lewat listing OKX.AI (acceptance pasar, terpisah dari A5.4). Paralel: D7 delivery.

---

## PEMBAGIAN TUGAS — DIEN (manusia) vs AGENT (per sesi #3)

> Aturan pembeda: kalau butuh **akun / uang / wallet interaktif / keputusan / konten
> kreatif / ngobrol sama Wangsit** → tugas Dien. Kalau **koding / konfig / verifikasi
> teknis** → agent bisa (tinggal minta).

### 🧑 HANYA DIEN yang bisa (agent tak bisa gantikan)

- [x] **D1. Buka & merge 2 PR ke `main`** — `feat/a-integration` + `feat/a-preseed`
  ```
  (keduanya sudah diuji **bebas konflik**). Butuh akses GitHub. Detail cara +
  hambatan → lihat bagian **MERGE KE MAIN** di bawah.
  ```
- [x] **D2. Deploy engine+gateway ke host publik HTTPS SELESAI ✅** — OVH shared VPS
  ```
  `https://api.cachetprotocol.xyz`; Cloudflare Full (strict), image immutable,
  corpus 5k, smoke public lulus. SimpleArt tetap sehat saat cutover.
  ```
- [ ] **D3. Daftarkan ASP di okx.ai** pakai Agentic Wallet Dien — terikat akun, agent tak bisa masuk.
- [x] **D4. URL cert page + addresses handover SELESAI:**
  ```
  `CERT_PAGE_BASE=https://cachet-six.vercel.app` aktif di VPS; cert #6 public 200.
  `addresses.testnet.json` main sudah `DEPLOYED` dengan address asli.
  ```
- [x] **D5. Credential OKX Payment API diperoleh dan dirotasi aman ✅**
  ```
  API key + secret + passphrase disimpan di password manager dan tidak masuk git/chat.
  OKX adalah Broker/facilitator; Cachet tidak membangun facilitator sendiri.
  ```
- [x] **D6. Keputusan resolver — SELESAI, TERNYATA SUDAH BENAR SEJAK AWAL ✅ (23 Jul):**
  ```
  Sempat salah arah: Dien nyaris bikin address resolver baru untuk dipegang sendiri
  (menyimpang dari rencana A1). Sebelum eksekusi, agent cek langsung on-chain:
  ChallengeManager.resolver() sudah TERKUNCI (set-once, `setResolver` — ubah =
  redeploy) ke `0x95005471397022acf0459a0b71818453fcfc4859`. Dikonfirmasi Dien:
  address itu SUDAH benar dan dipegang WANGSIT (bukan Dien, bukan placeholder).
  Jadi syarat A1 ("resolver beda dari gateway") SUDAH terpenuhi sejak deploy awal —
  TIDAK PERLU redeploy, TIDAK PERLU address baru. Address baru yang sempat dibuat
  Dien (`0xAb46707Cb336de50A68a241924957165d87040af`) tidak dipakai/diabaikan.
  C1 (backup kunci resolver) kini murni tanggung jawab Wangsit (dia pemegang key),
  bukan lagi item Dien.
  ```
  ```
  Catatan buat README.md: kalimat roadmap "oracle desentralisasi 3+ resolver" yang
  ditambah sebelumnya (§ Honest limitations) TETAP relevan dan tetap disimpan —
  resolver tunggal (siapa pun pemegangnya) tetap sentralisasi MVP yang diakui jujur,
  cuma sekarang dikonfirmasi pemegangnya benar sesuai rencana, bukan menyimpang.
  ```
- [ ] **D7. Delivery H6–H7:** rekam video demo, post X, submit Google Form (`< 27 Jul 22:59 UTC`).
  ```
  *(Agent bisa draft skrip video + teks README/X.)*
  ```
- [x] **D8. Top-up faucet** OKB/MockUSDT ke wallet gateway bila menipis (sekarang cukup).
- [x] **D9. Isi USD₮0 testnet ke buyer wallet `DEMO_CREATOR_ADDR` SELESAI ✅**

  (`0x8ca39bDb97b5C6b75425c0E494a886E57A937f7a`) — via faucet X Layer testnet,
  10 USD₮0 masuk, contract token dikonfirmasi cocok sebelum dipakai. Menutup A5.4.

### 🤖 AGENT bisa kerjakan (tinggal minta)

- [x] **M1. Mint sungguhan di testnet SELESAI ✅** — **cert #6 di X Layer testnet**, tx `0x28cb4e78…` status success, `ownerOf(6)`=DEMO_CREATOR, certData benar (declared 50, waiting +10s, coverage +365h). Gateway `chain=viem` → kontrak Wangsit asli. Explorer: `okx.com/web3/explorer/xlayer-test/tx/0x28cb4e78715a20c8991b7ea43d48366b5a2c4c92591744433176aa8fac9f02be`. **Golden Path verify→certify TERBUKTI di testnet.**
- [x] **M2. Dockerfile + konfig deploy SELESAI ✅** — baseline PR #20 sudah di-upgrade pada `feat/a-ovh-deploy` khusus shared OVH VPS: build live `linux/amd64` engine+gateway lulus, runtime non-root/healthy, Compose resource limit+persistent state valid, Caddy shared config valid, backup/rollback/runbook tersedia. → tinggal Dien eksekusi deploy (D2).
- [x] **M3. Draft teks listing ASP SELESAI ✅ (23 Jul)** — `asp-listing-draft.md` di root
  (LOKAL/untracked, seperti tracker ini): name/tagline (keputusan Dien: konsisten
  "Collateralized First-Seen Certificates for Digital Work"), short+long description,
  endpoint A2MCP `https://api.cachetprotocol.xyz`, tabel harga, 6 capabilities,
  disclosure §7-compliant (grep kata terlarang = nol), links (cert page BARU
  `https://cachetprotocol.vercel.app`, cert #15, tx explorer). README publik +
  disclosure sudah merged sebelumnya (PR #31). Tinggal Dien copy-paste ke form (D3).
- [ ] **M4. Draft skrip/urutan video demo** (Golden Path 4 langkah).
- [x] **M5. Integrasi kode OKX x402 v2 SELESAI + DIDEPLOY ✅** — custom v1

  diganti `@okxweb3/x402-fastify/core/evm`; X Layer Testnet + USD₮0 resmi, payTo
  wallet gateway, 45 test gateway + 5 MCP + typecheck + image linux/amd64 sehat.
  **Deploy production selesai (sesi #9):** `cachetctl deploy` ke VPS, image
  `sha-84c5ea2…`, smoke internal+publik hijau. Paid public smoke (A5.4) tinggal
  menunggu dana buyer wallet.
- [x] **M6. Operasi PR via `gh` tersedia** — Dien sudah login; PR #27 merged dan PR #28 terbuka.
- [ ] **M7. Wire CLIP embedding nyata** — **sengaja tidak dipasang pada VPS 2-vCore/4-GB saat ini**. Sebelum mengaktifkan, upgrade ke ≥4-vCore/8-GB atau pindahkan Cachet ke host terpisah; tier pHash tetap aktif dengan embedder fake.
- [ ] **M8. Rebase branch** bila `main` bergeser lagi + jalankan smoke test §6 saat integrasi.
- [ ] **M9. Aktifkan CI/CD production — PAUSED atas permintaan Dien.** PR #28 open dan

  semua check hijau; sisa admin Environment/secrets, CODEOWNER review+merge, publish
  image main, lalu manual dispatch+smoke pertama.

---

## MERGE KE MAIN — kondisi & cara singkirkan hambatan

**Kondisi (diuji sesi #3):** `origin/main`=`162c29b`. Kedua branch A **merge BERSIH** ke
main (nol konflik — perubahan B semua di folder `contracts/`+`packages/`+`docs/`).
Cukup **2 PR**: `feat/a-integration` (mencakup PR-1/3/4/5/6) + `feat/a-preseed`.

**Hambatan & solusinya:**

1. **`gh` belum login** di lingkungan agent → agent tak bisa buka/merge PR via CLI.
   **Solusi:** Dien jalankan `gh auth login` (atau set `GH_TOKEN`), lalu agent bisa
   `gh pr create`+`gh pr merge`. ATAU Dien merge manual di web github.com.
2. **Branch protection main** (require PR + 1 approval + code-owner) mungkin aktif →
   GitHub tak izinkan approve/merge PR sendiri. → **Solusi:** minta Wangsit approve PR-A
   (folder A tak butuh review B secara isi, hanya butuh 1 approval prosedural), ATAU
   Dien pakai admin-merge bila punya akses, ATAU longgarkan aturan sementara untuk merge ini.
3. **Jangan push langsung ke `main`** (aturan CLAUDE.md §5 + main = shared dgn Wangsit).
   Merge WAJIB lewat PR, bukan `git push origin main`.

---

## T0 — URGENT / prasyarat (harusnya H1, belum beres)

- [x] **T0.1 Buat wallet gateway BARU testnet-only** → `GATEWAY_PK` + `GATEWAY_ADDR` di `.env`. ✅ (Dien, 22 Jul)
- [x] **T0.2 Kirim `GATEWAY_ADDR` ke Wangsit** — set-once saat deploy. ✅ (Dien, 22 Jul)
- [x] **T0.3 Faucet OKB + MockUSDT ke wallet gateway.** ✅ (Dien, 22 Jul)
- [x] **T0.4 Review PR #7 milik B** (contract-gaps E2). ✅ Review sisi-A selesai (sesi #2).
  ```
  PR #7 = Vault+ChallengeManager+Deploy, sudah merged, murni folder B. Verdict: **solid, layak deploy.**
  Temuan (semua low, tidak memblokir): (a) `Deploy.s.sol` TIDAK menulis `addresses.testnet.json`
  otomatis — hanya `console.log`; update file itu manual, mudah lupa/salah tik. (b) Vault
  menyimpang dari tabel wiring §3.1/RFC-P3: `certificate` dibuat **immutable** (bukan `setCertificate`)
  & tidak ada `setGateway` — lebih AMAN, tapi divergensi dari interface beku tanpa baris changelog.
  Nol dampak ke A. → sampaikan ke Wangsit sebagai catatan, bukan blocker.
  ```
- [x] **T0.5 Keputusan gap — SEBAGIAN BESAR SELESAI (Wangsit tutup gap kode di main `162c29b`):**
  ```
  ✅ **G1** snapshot livenessWindow · ✅ **G2** coverage dinilai saat gugatan dibuka + redeploy ·
  ✅ **G3** earmark bond · ✅ **G4** komentar · ✅ **G5** matikan renounceOwnership. "Semua gap kode clear."
  Rekomendasi review-ku (T0.4) diikuti. **A1 & C1 SELESAI (→ D6, 23 Jul):** resolver
  sudah dipegang Wangsit sejak deploy awal (address `0x9500...4859`, terkonfirmasi),
  beda dari gateway — sesuai rencana. Backup kunci (C1) tanggung jawab Wangsit.
  ```

## A1 — Originality Engine (Python FastAPI, `services/engine/`) — target H1–H2

- [x] A1.1 Scaffold FastAPI + `load_dotenv(find_dotenv())`; port 8100. **Py 3.13** (bukan 3.11 — 3.11/3.12 tak terpasang; 3.13.14 ada). Factory `create_app`.
- [x] A1.2 `POST /hash` → `{asset_sha256, phashes[4], embedding_commit}`. keccak256 via pycryptodome.
- [x] A1.3 `POST /index` → SQLite `entries(...)` + vector index. **entry_id auto-increment (id CORPUS, ≠ entryId on-chain)** — dicatat di README.
- [x] A1.4 `POST /query` → nearest pHash (Hamming numpy XOR+popcount, pilih kandidat by matched↓ lalu min_h↑) + nearest embedding.
- [x] A1.5 verdict + distinctiveness. Urutan: NEAR_DUP > GRAY_ZONE > ORIGINAL. insurable = (verdict==ORIGINAL).
- [x] A1.6 C2PA reader — **fallback JUMBF aktif** (lib `c2pa` tak dipasang, lihat catatan ML di bawah). synthid_checked selalu false.
- [x] A1.7 **29 test** (pytest) — test_verdict/hashing/store/api/c2pa. Semua tanpa ML.
- [x] **Acceptance TERPENUHI:** `pytest` 29/29 hijau; smoke uvicorn nyata — `/query` versi resize → NEAR_DUP min_hamming=0.

**Keputusan arsitektur (de-risk py3.13):** Embedder & VectorIndex di belakang `Protocol` → tier deterministik pHash berdiri sendiri. Produksi: `ClipEmbedder`+`FaissIndex`; test/tanpa-torch: `FakeEmbedder`+`NumpyIndex`. Seluruh test jalan tanpa torch/faiss/c2pa.

**⚠️ Temuan ML (untuk A5):** `pip install -r requirements-ml.txt` GAGAL di py3.13 — `c2pa`→`py3exiv2` gagal build. Dampak A1 = nol. Opsi A5: turun ke py3.12, ATAU pasang torch+open_clip saja (c2pa pakai fallback JUMBF, faiss opsional→numpy). Jangan blokir A3 stub.

**Catatan fixture:** "crop 10%" diuji sebagai 5%/sisi (≈10%/dimensi). Crop 10%/sisi (20%/dim, 36% area) di luar toleransi pHash 256-bit — dibuktikan lewat diagnostik, bukan asumsi.

## A2 — Pre-seed corpus + demo fixture (`scripts/`) — target H2

- [x] A2.1 `scripts/preseed.py` — sumber synthetic/wikimedia/manifest; simpan hash+embedding+URI; checkpoint tulis-atomik + resume; engine HTTP atau in-process.
- [x] A2.2 `scripts/demo_fixtures.py` — 4 korban seed **TERKURASI** (tahan crop 5%/sisi margin ≥2 hash ≤20, saling non-near-dup) + salinan resize/crop/recolor/JPEG → verify NEAR_DUP. Bisa pakai gambar nyata di `scripts/demo/originals/`.
- [x] A2.3 `scripts/corpus_coverage.py` → `corpus-coverage.md` (disclosure jujur per-sumber).
- [x] **Acceptance TERPENUHI:** 5k sintetis ter-index ~40s; **query 5k corpus 241 ms (`<2s`)**; 12 gambar Wikimedia nyata ter-ingest via network 0 error; 7 test hijau.

**Catatan:** embedding corpus preseed in-process = placeholder (fake) sampai CLIP di-wire (A5) — tier pHash (yang menangkap salinan) tetap valid. Seed korban dikurasi lewat scan (bukan acak) supaya `demo verify` stabil.

## A3 — Gateway (Node 20/TS Fastify, `apps/server/` + `apps/mcp-server/`) — target H2–H3

- [x] A3.1 Scaffold Fastify + REST §3.3 (dotenv root). MCP tools = **PR-4 SELESAI** (`apps/mcp-server`).
- [x] A3.2 x402 middleware **MIGRASI v2 SELESAI + LIVE PRODUCTION (M5)**: SDK

  resmi OKX Fastify, `PAYMENT-REQUIRED`/`PAYMENT-SIGNATURE`/`PAYMENT-RESPONSE`,
  verify sebelum handler dan settle hanya setelah respons sukses;
  `X402_BYPASS=1` dev. 402 challenge asli terverifikasi publik (sesi #9).
- [x] A3.3 Signer EIP-712 dari `GATEWAY_PK` (`src/signer.ts`) — recover-verified di test.
- [x] A3.4 `ChainClient` interface + `StubChainClient` yang meniru aturan kontrak nyata (bukan sekadar sukses).
- [x] A3.5 Alur `register_and_mint` atomik; tolak NEAR_DUP (409); premi BigInt floor dari `chain.quotePremium`; response cert_id+entry_id+cert_page_url+profile; menyemai registry (F10).
- [x] A3.6 `commit_work` + helper rumus (kembalikan formula+note); mint terima `salt` opsional (reveal); commit sekali-pakai.
- [x] A3.7 `challenge_certificate` → instruksi approve ke **VAULT** + bond + langkah + warning (P6).
- [x] A3.8 `get_certificate` — status dari `isCoverageActive` (chain = sumber kebenaran) + PENDING/EXPIRED/REVOKED/NOT_INSURABLE. **Bug ketemu & fix:** semula pakai jam gateway utk ACTIVE.
- [x] A3.9 Rate limit + bodyLimit 15 MB + idempotensi per `request_id` + error `{error:{code,message}}`.
- [x] A3.10 `DEMO_MODE=1` verify balas fixture (ORIGINAL/NEAR_DUP) tanpa engine.
- [x] **Acceptance A3 TERPENUHI PENUH:** PR-3 25 test + PR-4 (32 server + 5 MCP) hijau. E2e: verify→mint(cert 1)→get_cert(PENDING)→re-mint→NEAR_DUP 409; **tanpa bayar→402+PAYMENT-REQUIRED**; **MCP client→tools→gateway→engine+stub** (verify=ORIGINAL, mint=cert 1, get_cert=PENDING).

**PR-4 (`feat/a-mcp-x402`, base PR-3):** x402 di `apps/server/src/x402/` + `apps/mcp-server/` (6 tool MCP forward ke gateway). Pushed.

## A4 — Watch worker (`services/watch/`) — target H3–H4

- [x] A4.1 Cron node-cron (`CRON_SCHEDULE` 6 jam) + trigger manual (`POST /rescan`, `pnpm rescan`). Primitif baru engine `**POST /neardups**` (entri NEAR_DUP > since; mint tolak near-dup jadi salinan masuk lewat /index).
- [x] A4.2 Match → webhook alert + draft challenge (bukti: entri diawasi + timestamp) + dashboard-lite (`GET /alerts`). **Email tak dikirim di MVP** (jujur, dicatat).
- [x] A4.3 State `last_checked` per subscription (worker punya `watch.json` sendiri, tak menulis file gateway; titik periksa maju → tak dobel-alert).
- [x] **Acceptance TERPENUHI:** mint X→subscribe→register salinan X′→`pnpm rescan`→**1 alert + webhook diterima** (copy_detected, cert 1, copy entry 2, draft challenge). engine 33 + gateway 34 + watch 4 test hijau.
- [x] *Potong-scope siap: `POST /rescan` / `pnpm rescan` = tombol "re-scan now".*

**Catatan lintas-folder:** Watch = fitur menyeluruh menyentuh engine (+/neardups) + gateway (/v1/watch simpan fingerprint + rekam mint) + worker. Gateway `/v1/watch` kini butuh cert di-mint via gateway ATAU sertakan `image_b64`.

## A5 — Integrasi chain nyata + ASP okx.ai — target H4–H5

- [x] A5.1 `**ViemChainClient` SELESAI** (`apps/server/src/chain/viem.ts`) — swap stub via `CHAIN_MODE` (auto=viem bila ADDR_CERTIFICATE terisi). Baca ADDR_*/RPC dari env. Tinggal isi `.env` saat B deploy testnet.
- [x] A5.2 `ensureReady()` approve payToken ke **Vault** (maxUint256) saat start; premi/bond dibaca dari chain (`quotePremium`/`fraudBondAmount`), tak hardcode.
- [x] **Verifikasi lokal (menutup celah E3):** `apps/server/scripts/local-anvil-e2e.sh` deploy kontrak B ke anvil (chain-id 1952) → gateway CHAIN_MODE=viem → verify(premi chain)→registerAndMint on-chain(cert 1, ownerOf=creator)→PENDING→ACTIVE→challenge. **Semua lolos.** 34 test stub tetap hijau.

- [x] **Kontrak B SUDAH deploy testnet** (`.env` A terisi, wallet terdanai, wiring cocok) dan **mint testnet nyata selesai** (cert #6; lihat M1).

- [x] A5.3 Deploy engine+gateway ke host publik HTTPS → **D2 SELESAI** (`https://api.cachetprotocol.xyz`; health 200, unpaid verify 402, cert #6 200, corpus 5k).
- [x] **A5.4 SELESAI PENUH (sesi #9)** via `apps/server/scripts/x402-buyer-smoke.mts`

  (buyer OKX resmi, bukan simulasi): paid `/v1/verify` 402→pay→200 (tx settle
  `0x4aa74b24…`); paid `/v1/mint` 402→pay→200, cert #15 ORIGINAL/insurable
  on-chain nyata (tx mint `0x564ccc5e…`, tx settle `0xa3936e07…`),
  `GET /v1/cert/15` publik ACTIVE. Golden Path x402 sungguhan terbukti utuh.
- [ ] A5.5 Registrasi ASP okx.ai → **D3** (akun Dien), setelah A5.4 direct paid smoke.
- [x] A5.6 `CERT_PAGE_BASE` dari Wangsit → **D4 SELESAI**.
- [x] **Acceptance:** x402 sungguhan → profile sah ✅; mint → NFT di explorer (cert #15) ✅.

  (Panggilan lewat MCP server eksternal belum diulang terpisah — REST gateway
  yang jadi payment authority sudah terbukti; MCP hanya thin adapter.)

**Blokir A5 sisa = akun/ops ASP okx.ai (D3) saja.** Deploy, kontrak, API publik,
dan protokol x402 (verify + mint, paid nyata) semuanya live dan terverifikasi
end-to-end. Pembagian tugas lengkap → bagian **PEMBAGIAN TUGAS** di atas.

## H6–H7 — Delivery (lihat `docs/delivery_implementation_plan.md`)

- [ ] Video demo (jalur nyata; DEMO_MODE hanya cadangan latihan) · README · X post · Google Form sebelum 27 Jul 22:59 UTC

---

## CATATAN INTEGRASI YANG SERING BIKIN GAGAL

- Mint revert `WrongPremium`/`WrongFraudBond` → gateway tidak baca parameter dari chain.
- `NotGateway` → `GATEWAY_ADDR` saat deploy B bukan wallet ini (butuh redeploy B, mahal — sebab T0.2 harus final).
- `ERC20InsufficientAllowance` → approve-nya bukan ke Vault.
- `ERC721InvalidReceiver` → penerima kontrak tanpa `onERC721Received` (cek Agentic Wallet).
- Saat demo `waitingPeriod`/`livenessWindow` DIPERCEPAT via `PrepareDemo.s.sol` — jangan asumsikan 72 jam/48 jam.
- `entryId`/`certId` mulai dari 1; `0` = tidak ada.

---

## LOG SESI (append-only, terbaru di bawah)


| Tanggal    | Sesi | Yang dikerjakan                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  | Next                                                                                                                 |
| ---------- | ---- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| 2026-07-22 | #1   | Baca ide v2.1 + technical plan + RFC-001 + contract-gaps + seluruh kontrak B & `packages/contracts-abi/`; simpan ke memory agent; buat tracker ini. Belum ada kode.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          | T0.1–T0.3 (wallet gateway → kirim ke B) lalu mulai A1                                                                |
| 2026-07-22 | #2   | Dien konfirmasi T0.1–T0.3 selesai. Review PR #7 (Vault+ChallengeManager+Deploy) → verdict solid + 2 temuan low. Susun rekomendasi gap G1/G2/G3/G5/C1/A1. Update tracker.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         | Dien relay rekomendasi T0.5 ke Wangsit; lalu mulai A1.1 (scaffold engine)                                            |
| 2026-07-22 | #2   | Susun `be-plan.md`: rencana implementasi A1–A4 (python3.13+venv, pnpm self-contained tanpa root workspace, ABI via `file:` dep, 5 PR berurutan PR-1 engine → PR-5 watch, SQLite bersama `data/cachet.db`).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       | Eksekusi PR-1 `feat/a-engine-core` (A1)                                                                              |
| 2026-07-22 | #2   | **PR-1 selesai:** engine A1 penuh di `services/engine/` (13 modul + 5 file test), venv py3.13, 29 test hijau, smoke uvicorn nyata OK (resize→NEAR_DUP min_hamming=0). Embedder/VectorIndex di belakang Protocol → jalan tanpa torch. Temuan: ML deps gagal resolve di py3.13 (c2pa→py3exiv2) — ditunda ke A5.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    | Push + buka PR-1; lalu PR-2 (A2) / PR-3 (A3)                                                                         |
| 2026-07-22 | #2   | **PR-2 selesai:** `scripts/` preseed+demo+coverage (11 modul + 4 test, 7 hijau). Benchmark: 5k index ~40s, query 241ms, 12 wikimedia live. Belajar mahal: branch harus bertumpu di atas PR-1 (main belum punya engine) — feat/a-preseed di-rebase ke feat/a-engine-core. Seed korban dikurasi 2× (curation harus pakai fungsi render produksi, bukan replika).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   | Push PR-1+PR-2; lalu PR-3 (A3 gateway) bertumpu di atas PR-1                                                         |
| 2026-07-22 | #2   | Push PR-1 & PR-2 ke origin (branch di-track).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                | Buka PR di web (base PR-2 = PR-1)                                                                                    |
| 2026-07-22 | #2   | **PR-3 selesai & di-push:** `apps/server/` gateway core (18 modul src + 4 test, 25 hijau) — REST §3.3, EIP-712 signer, StubChainClient (meniru error kontrak), profil §3.2, idempotensi, DEMO_MODE. E2e nyata engine+gateway+stub OK. Bug ketemu: status ACTIVE harus dari chain isCoverageActive bukan jam gateway. MCP+x402 ditunda ke PR-4.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               | PR-4 (x402+MCP) atau PR-5 (A4 Watch)                                                                                 |
| 2026-07-22 | #2   | **PR-4 selesai & di-push** (`feat/a-mcp-x402`, base PR-3): x402 payment guard di `apps/server/src/x402/` (402+PAYMENT-REQUIRED, harga §1.3, facilitator verify→settle, bypass dev) + `apps/mcp-server/` (6 tool MCP forward ke gateway). 32 test server + 5 MCP hijau; e2e: tanpa bayar→402, MCP client roundtrip OK. Facilitator OKX nyata di-wire di A5.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   | PR-5 (A4 Watch) lalu A5                                                                                              |
| 2026-07-22 | #2   | **PR-5 selesai & di-push** (`feat/a-watch`, base PR-4): Watch menyeluruh — engine `POST /neardups` (+4 test, engine 33 total), gateway `/v1/watch` simpan fingerprint + rekam mint (gw 34 test), worker `services/watch/` cron+rescan+webhook+draft challenge (4 test). E2e nyata: subscribe→register salinan→rescan→webhook diterima.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       | **A5**: ViemChainClient + deploy + ASP okx.ai                                                                        |
| 2026-07-22 | #2   | **PR-6 selesai & di-push** (`feat/a-integration`, base PR-5): A5 `ViemChainClient` (swap stub via CHAIN_MODE) + `local-anvil-e2e.sh`. **Verifikasi emas:** deploy kontrak B ke anvil → gateway viem → registerAndMint on-chain (cert nyata, ownerOf), PENDING→ACTIVE, challenge — semua lolos (menutup E3). Debug: gateway stub basi port 8793 sempat menutupi bug (fixed pakai port bersih).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                | Sisa A5 (deploy publik, smoke §6, ASP) tunggu B deploy; lalu delivery                                                |
| 2026-07-22 | #3   | Cek kondisi nyata: Wangsit **deploy 4 kontrak ke testnet** + tutup gap G1–G5 (main `162c29b`). `.env` Dien terisi alamat asli; on-chain wallet gateway terdanai (0.2 OKB + 776 mUSDT), wiring cocok, waiting=10s. Uji merge: **PR-6 & PR-2 bebas konflik**. Update tracker: STATUS, T0.5 (gap ditutup B), A5, + section **PEMBAGIAN TUGAS (Dien vs agent)** & **MERGE KE MAIN**.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         | Merge (Dien: gh auth / web) · lalu mint testnet (agent M1) / draft deploy+listing                                    |
| 2026-07-22 | #3   | Dien `gh auth login`. **Merge ke main SELESAI:** PR #18 (integration) + #19 (preseed) MERGED. Sinkron local main ke `3d94c95` (perubahan Dien .gitignore+docs → `git stash@{0}`). Bersihkan polusi anvil-ku di `contracts/`.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     | M1, M2                                                                                                               |
| 2026-07-22 | #3   | **M1 SELESAI:** mint testnet nyata cert #6 (tx success, ownerOf=DEMO_CREATOR). **M2 SELESAI:** Dockerfile+compose (PR #20 merged). ⚠️ Dien: `git stash pop` untuk kembalikan .gitignore+docs.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    | D-series (deploy D2, ASP D3, minta cert-page/facilitator D4/D5) + delivery H6–H7                                     |
| 2026-07-22 | #4   | **Spec shared OVH disetujui + implementasi siap:** engine/gateway image `linux/amd64` non-root dibangun dan smoke-tested; Compose limit resource+persistent state, Caddy Cloudflare Origin TLS, preflight, backup/rollback, pause/resume, dan runbook dibuat di `feat/a-ovh-deploy`. Kebijakan: SimpleArt prioritas; Cachet dipause saat deploy SimpleArt. CLIP sengaja off sampai VPS ≥4-vCore/8-GB atau host terpisah.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         | Eksekusi D2 di VPS + Cloudflare; lalu smoke publik dan D3/D5 ASP x402                                                |
| 2026-07-22 | #5   | **D2/A5.3 SELESAI:** `api.cachetprotocol.xyz` live via Cloudflare Full (strict)+Origin CA pada shared OVH 2c/4GB. Image immutable `sha-081f8f6…`, engine private/no host port, gateway loopback, corpus 5k, smoke eksternal health=200/unpaid=402/cert6=200. SimpleArt tetap healthy. Swap 2GB safety net aktif. CLIP tetap off. Facilitator x402 belum tersedia; cert page sementara endpoint JSON API.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         | D3/D5 ASP+facilitator; D4 URL cert-page Wangsit; lalu smoke x402 sungguhan + delivery                                |
| 2026-07-22 | #6   | `CERT_PAGE_BASE=https://cachet-six.vercel.app` aktif production; cert #6 public. PR #27 deploy merged. CI/CD guarded dibuat di PR #28: PR test/build no-push, main publish image immutable, manual Environment deploy dengan backup/SimpleArt gates/rollback/transient GHCR. Semua 6 check hijau. Blocker: akun Dien hanya WRITE, jadi Wangsit/admin harus membuat `ovh-production`; dua PAT GHCR belum dibuat.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  | Wangsit review + environment admin; Dien buat PAT read/write; lalu merge dan dispatch deploy                         |
| 2026-07-22 | #7   | Atas keputusan Dien, CI/CD **dipaused dan dicatat belum selesai**: PR #28 tetap open/unmerged; Environment, deploy key, PAT, publish, dan dispatch pertama masih pending. Audit tracker mengalihkan prioritas non-CI ke D3/D5/D6/D7.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             | D3 listing ASP → D5 facilitator; paralel D6 resolver + persiapan D7 delivery                                         |
| 2026-07-22 | #8   | **D5 credential selesai + M5 kode selesai lokal:** tracker lama dikoreksi—Cachet adalah seller, OKX adalah Broker. Custom x402 v1 diganti SDK resmi Fastify v2 pada `feat/a-okx-x402-v2`; testnet `eip155:1952`, USD₮0 resmi, payTo gateway. 45 gateway + 5 MCP test/typecheck hijau; image linux/amd64 build dan health 200. CI/CD tetap tidak disentuh.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        | Commit/push M5, deploy gateway manual, input credential via `sudoedit`, lalu A5.4 paid smoke                         |
| 2026-07-22 | #9   | Sesi Codex sebelumnya macet di step deploy VPS karena kena **limit usage Codex sendiri** (bukan blocker nyata) tepat sebelum backup+deploy. Lanjutkan penuh: cek VPS (image lama `081f8f6…` masih jalan, tapi `.env` ternyata **sudah** berisi credential OKX — langkah sudoedit sesi lalu sudah beres), update `deploy.env` ke SHA merge `84c5ea2…`, jalankan `cachetctl deploy` (backup ok, pull ok, engine+gateway update healthy, corpus 5000, smoke internal+publik hijau setelah retry transient 503). Lanjut buktikan A5.4: tulis `apps/server/scripts/x402-buyer-smoke.mts` (buyer OKX-compatible pakai `@okxweb3/x402-evm`+`@okxweb3/x402-core`, fix bug `toClientEvmSigner` vs raw viem WalletClient yang tak punya `.address`). Hasil nyata ke `api.cachetprotocol.xyz`: 402 asli diterima, EIP-3009 ditandatangani & dikirim benar, gagal HANYA di settlement Broker karena `DEMO_CREATOR_ADDR` USD₮0=0 (OKB cukup). Protokol x402 v2 terbukti utuh end-to-end; satu-satunya sisa = dana buyer wallet.                                                                                                                                                                                           | Dien top-up USD₮0 ke `DEMO_CREATOR_ADDR` (D9) → re-run buyer smoke → `/v1/mint` + cek explorer → tutup A5.4 → D3 ASP |
| 2026-07-22 | #10  | **A5.4 DITUTUP.** Wangsit tanya soal asset/scheme facilitator (MockUSDT vs token OKX, EIP-3009 vs Permit2) — dijawab dari bukti nyata sesi #9 (bukan tebakan): asset = `USD₮0` OKX sendiri (`name()`/`symbol()`/`decimals()` on-chain dikonfirmasi = "USD₮0"/6), skema = EIP-3009 (SDK signing sukses). Jadi skenario upgrade+redeploy kontrak MockUSDT tidak relevan. Dien tanya token faucet: address pertama yang dikasih (`0xf6d088…d448907`) ternyata **faucet dispenser contract**, bukan token (`name()`/`symbol()` revert, bytecode proxy) — dikoreksi sebelum diklaim salah token. Dien klaim 10 USD₮0 dari faucet X Layer ke `DEMO_CREATOR_ADDR`, dicek `balanceOf` on-chain = 10.000000 cocok. Re-run `x402-buyer-smoke.mts`: **paid `/v1/verify` 402→pay→200 sukses** (settle tx `0x4aa74b24…`); refactor script terima `ROUTE`/`BODY` env, generate gambar unik (PIL) untuk hindari NEAR_DUP, **paid `/v1/mint` 402→pay→200 sukses** — cert **#15** ORIGINAL/insurable, tx mint `0x564ccc5e…`, tx settle `0xa3936e07…`, `GET /v1/cert/15` publik ACTIVE owner=DEMO_CREATOR_ADDR. Golden Path x402 sungguhan (bukan DEMO_MODE) terbukti utuh dari verify sampai mint dengan pembeli eksternal nyata. | D3 registrasi ASP okx.ai, lalu ulangi Golden Path lewat listing OKX.AI (acceptance pasar)                            |
| 2026-07-22 | #11  | Bersihkan `be-tracker.md`: hapus semua entity HTML basi (`&amp;`/`&gt;`/`&lt;`) dan perbaiki paragraf "MERGE KE MAIN" + aturan folder A yang korup (karakter awal baris hilang di sesi lampau) — supaya file tak lagi kena mode "code only" karena dianggap contains HTML/JSX/MDX (root cause-nya bare `<branch>` di luar backtick). Dien diminta jelaskan D6 (kenapa resolver harus beda dari gateway + kenapa butuh backup key) — dijawab lengkap. Dien putuskan: **untuk kebutuhan hackathon, resolver dipegang Dien sendiri** (bukan Wangsit/luar seperti rencana awal A1), tapi via address baru terpisah dari `GATEWAY_ADDR`. Diminta jujur diungkap: tambah 1 kalimat roadmap di `README.md` § Honest limitations — resolver akan pindah ke oracle desentralisasi (3+ resolver independen) pasca-hackathon. D6 ditandai sebagian: keputusan siapa pegang sudah ada, tapi address baru belum dibuat/dikirim ke Wangsit dan C1 (rencana backup key) belum dijawab Dien. | Dien: (1) buat address resolver baru, kirim ke Wangsit untuk `RESOLVER_ADDR`; (2) jawab rencana backup key (C1); lalu D3 ASP |
| 2026-07-23 | #12  | Dien kasih address resolver baru (`0xAb46707Cb336de50A68a241924957165d87040af`) untuk dikirim ke Wangsit. **Sebelum dieksekusi, agent cek dulu on-chain** (bukan asumsi): `ChallengeManager.resolver()` ternyata **sudah ke-lock** (pola `setResolver`/`_lockWiring` set-once, "ubah = redeploy", sama seperti `setGateway`) ke `0x95005471397022acf0459a0b71818453fcfc4859` — beda dari address baru Dien. Ini mengubah task sepenuhnya: kirim address baru saja tidak akan berfungsi, butuh redeploy kalau memang perlu ganti. Ditanya balik ke Dien siapa pemegang address terkunci itu — **Dien konfirmasi: itu Wangsit, sudah benar sejak awal.** Jadi syarat A1 (resolver beda dari gateway) sudah terpenuhi dari awal deploy, tidak ada yang perlu diubah. Address baru Dien tidak dipakai. D6 & T0.5-sisa ditutup penuh; C1 (backup key) kini murni tanggung jawab Wangsit. | D3 registrasi ASP okx.ai (satu-satunya blocker A5 tersisa) |
| 2026-07-23 | #13  | **PR #31 merged ke main** (`e18bf84`): README roadmap disclosure resolver + `x402-buyer-smoke.mts` (lewat branch `feat/a-resolver-disclosure-x402-smoke`, bukan push langsung — aturan §5). **M3 SELESAI:** `asp-listing-draft.md` lokal (English, §7-compliant, modular per field form). Diskusi tagline: alternatif B/C/D ditawarkan, Dien pilih **A konsisten** ("Collateralized First-Seen Certificates for Digital Work"); dicatat juga CLIP (M7) tidak mengubah nama/tagline. **Cert page pindah domain:** Dien ganti ke `https://cachetprotocol.vercel.app` (cek live 200) → `CERT_PAGE_BASE` di `/opt/cachet/.env` VPS di-update via sed, gateway container di-recreate, smoke hijau (healthz 200, unpaid 402, `cert/15` sekarang mengembalikan URL baru). | D3: Dien buka okx.ai + Agentic Wallet, copy-paste dari `asp-listing-draft.md`; setelah listing accepted → ulangi Golden Path lewat OKX.AI (acceptance pasar) |


