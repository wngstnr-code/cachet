# CACHET — Technical Implementation Plan v1

> **Basis:** `cachet_idea_v2.md` (Ideation Brief v2.1 FINAL).
> **Untuk siapa:** dua orang builder (**Person A = Dien**, **Person B = teman**) beserta AI agent masing-masing (Claude / Codex / Gemini). Dokumen ini ditulis agar sebuah AI agent bisa mengeksekusi task-nya **tanpa konteks lain** — semua spec, interface, dan acceptance criteria ada di sini.
>
> **Aturan emas kolaborasi:** Workstream A dan B **sepenuhnya independen** setelah §3 (Interface Freeze) disepakati. A tidak menunggu B, B tidak menunggu A, sampai hari Integrasi. **Person B TIDAK punya dan TIDAK butuh akses ke repo Veritas milik Dien** — semua yang B butuhkan ada inline di dokumen ini.

---

## 1. KONTEKS & TUJUAN

### 1.1 Apa yang dibangun

**Cachet** = ASP (Agent Service Provider) di marketplace **okx.ai**, dipanggil oleh agent lain / kreator via **x402** (pay-per-call stablecoin). Fungsi: membuktikan sebuah gambar **"first-seen"** (bukan salinan dari yang sudah terdaftar), menerbitkan **sertifikat on-chain ber-jaminan** yang **ikut berpindah ke pembeli aset**, bisa **digugat (challenge)** oleh siapa pun dengan bukti, dan **diawasi terus** (Watch).

**Tagline produk:** *"Proof it's first. Money if it's not."*

### 1.2 Scope MVP (KEPUTUSAN FINAL — jangan tambah scope)

Dibangun beneran (end-to-end):

| # | Fitur | Ringkas |
|---|---|---|
| 1 | **Verify** | cek gambar vs registry: near-duplicate (ensemble pHash, deterministik) + distinctiveness (embedding, advisory) → JSON "Originality Profile" |
| 2 | **Certify & Mint** | mint ERC-721 "First-Seen Certificate" di **X Layer** + fraud bond + declared value + waiting period |
| 3 | **Transferable coverage** | coverage melekat ke NFT — transfer NFT = transfer coverage (otomatis by design) |
| 4 | **Challenge** | gugat sertifikat dengan bond + bukti; resolve → payout ke pemegang + bounty ke penantang, atau slash bond penantang |
| 5 | **Commit-Reveal** | kunci hash komitmen privat sebelum karya publik (anti registry-sniping) |
| 6 | **Watch** | cron re-scan: sertifikat aktif dicek vs registrasi baru; match → alert + draft challenge otomatis |

**TIDAK dibangun (roadmap, hanya didokumentasikan):** kolam staking Fase-3, rev-share pemanggil (F15), reputasi ERC-8004 (F16), seasoning otomatis on-chain (ditampilkan sebagai umur sertifikat + jumlah challenge yang selamat — dihitung dari data yang memang ada), zkML, C2PA anchoring penuh (MVP hanya **membaca** metadata C2PA bila ada).

**Penyederhanaan MVP yang jujur (WAJIB ditulis di README & disclosure):**
- **Adjudikasi challenge = admin/operator (kami) untuk MVP**, dengan jendela liveness publik. Roadmap: optimistic oracle terdesentralisasi. Jangan mengklaim "trustless adjudication".
- Verdict verify ditandatangani **satu signer gateway** (EIP-712). Roadmap: quorum multi-oracle.
- Registry coverage = korpus pre-seed + semua yang ter-register di Cachet. **Bukan** "seluruh internet".

### 1.3 Parameter produk (nilai default MVP)

| Parameter | Nilai MVP | Catatan |
|---|---|---|
| Ambang near-duplicate (per hash) | Hamming ≤ 25 dari 256 bit (≈90% mirip) | verdict `NEAR_DUP` bila ≥2 dari 4 hash ensemble match |
| Zona abu-abu embedding | cosine similarity 0.90–0.97 ke tetangga terdekat | `GRAY_ZONE` → boleh mint, **tidak insurable** |
| Distinctiveness score | 1 − max cosine similarity, skala 0–1 | advisory saja |
| Fraud bond | 5 USDT flat (testnet: token dummy) | di-slash saat fraud terbukti |
| Coverage | = declared value, **plafon MVP 100 USDT** | jujur: "coverage terbatas selama bootstrap" |
| Premi | 2% × declared value | masuk vault |
| Waiting period coverage | 72 jam setelah mint | klaim sebelum itu ditolak |
| Masa coverage | 365 hari (sertifikat tetap perpetual) | |
| Challenge bond | 10 USDT flat | penantang salah → slash (50% ke pemegang cert, 50% vault) |
| Challenge liveness | 48 jam | |
| Bounty penantang benar | fraud bond kreator + 50% premi | |
| Harga x402 `verify` | 0.02 USDT | |
| Harga x402 `commit` | 0.01 USDT | |
| Harga x402 `register_and_mint` | 0.5 USDT + premi 2% | |
| Harga x402 `watch` (langganan) | 0.1 USDT / 30 hari / aset | |
| `get_certificate` / `get_profile` | gratis | |

### 1.4 Keputusan teknis terkunci

- **Chain: X Layer** (EVM, gas OKB). Development & testing di **X Layer Testnet**; deploy final ke testnet dulu, pindah mainnet hanya jika waktu tersisa & gas tersedia (lihat Open Flags §10).
- **Kode: hybrid** — Person A me-reuse logika dari repo Veritas milik Dien (pHash Gen1, pola oracle UHI9) sebagai **referensi internal A saja**. Kontrak & service ditulis baru, bersih, khusus Cachet.
- **Bahasa/stack:** Solidity + Foundry (B) · Python FastAPI (engine, A) · Node/TypeScript Fastify (gateway/MCP/x402, A) · site statis viem (cert page, B).

---

## 2. ARSITEKTUR

```
                        ┌──────────────────────────────────────────────┐
  Agent lain /          │  GATEWAY  (Node/TS, Person A)                │
  kreator / AI    ────▶ │  - endpoint MCP + REST                       │
  (via okx.ai,          │  - x402 payment guard (OKX Payment SDK)      │
   bayar x402)          │  - EIP-712 signer utk verdict                │
                        │  - submit tx mint/challenge ke chain          │
                        └───────┬──────────────────────┬───────────────┘
                                │ HTTP (localhost/private)             │ JSON-RPC (viem)
                                ▼                      ▼
                 ┌──────────────────────────┐   ┌─────────────────────────────────┐
                 │ ORIGINALITY ENGINE       │   │ X LAYER (Solidity, Person B)    │
                 │ (Python FastAPI, A)      │   │ - CachetRegistry (+CommitReveal)│
                 │ - ensemble pHash ×4      │   │ - CachetCertificate (ERC-721)   │
                 │ - embedding (open_clip)  │   │ - CachetVault (bond/premi/claim)│
                 │ - FAISS index + SQLite   │   │ - ChallengeManager              │
                 │ - pre-seed corpus        │   └─────────────┬───────────────────┘
                 └──────────────────────────┘                 │ read-only (viem)
                                ▲                             ▼
                 ┌──────────────┴───────────┐   ┌─────────────────────────────────┐
                 │ WATCH WORKER (cron, A)   │   │ CERTIFICATE PAGE (statis, B)    │
                 │ re-scan aktif cert vs    │   │ /cert/:id — bukti publik:       │
                 │ registrasi baru → alert  │   │ status, umur, challenge history │
                 └──────────────────────────┘   └─────────────────────────────────┘
```

**Prinsip pemisahan:** B hanya bergantung pada **§3 (interface freeze)**. A meng-compile kontrak B dari spec §3 sendiri (atau stub) sampai hari integrasi. Certificate page milik B membaca **langsung dari chain**, tidak menyentuh backend A sama sekali.

---

## 3. INTERFACE FREEZE ⚠️ (dibekukan Hari-1; perubahan = wajib sepakat dua pihak)

Bagian ini adalah **kontrak antar-workstream**. Kalau A dan B sama-sama patuh pada bagian ini, integrasi hari-4 tinggal menyambungkan alamat.

### 3.1 Solidity interfaces (Person B implementasikan persis; Person A pakai ABI ini)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// ---------- CachetRegistry (termasuk commit-reveal) ----------
interface ICachetRegistry {
    /// Kreator mengunci hash komitmen SEBELUM karya publik. Murah, privat.
    /// commitHash = keccak256(abi.encodePacked(phash1, salt, creator))
    function commit(bytes32 commitHash) external;
    /// timestamp komitmen (0 jika tak ada)
    function commitTimestamp(bytes32 commitHash) external view returns (uint64);

    /// Registrasi entri. HANYA bisa dipanggil gateway (trusted signer MVP)
    /// bersamaan dengan mint. phashes = 4 hash ensemble; embCommit = keccak256(embedding bytes).
    function register(
        bytes32[4] calldata phashes,
        bytes32 embCommit,
        address creator,
        bytes32 revealedCommit,   // 0x0 jika tanpa commit-reveal
        string calldata assetURI
    ) external returns (uint256 entryId);

    function entryCount() external view returns (uint256);
    function getEntry(uint256 entryId) external view returns (
        bytes32[4] memory phashes,
        bytes32 embCommit,
        address creator,
        uint64 registeredAt,
        uint64 commitAt,          // timestamp komitmen bila ada (lebih tua dari registeredAt)
        string memory assetURI
    );

    event Committed(bytes32 indexed commitHash, uint64 timestamp);
    event Registered(uint256 indexed entryId, address indexed creator, bytes32 phash0, uint64 timestamp);
}

/// ---------- CachetCertificate (ERC-721; NFT = sertifikat = pembawa coverage) ----------
interface ICachetCertificate /* is ERC721 */ {
    struct CertData {
        uint256 entryId;        // link ke registry
        uint256 declaredValue;  // dalam token pembayaran (6 desimal)
        uint64  mintedAt;
        uint64  coverageStart;  // mintedAt + waitingPeriod
        uint64  coverageEnd;    // coverageStart + 365 hari
        bool    insurable;      // false utk gray-zone / ditolak underwriting
        bool    revoked;        // true bila kalah challenge
        uint32  challengesSurvived;
    }

    /// Mint oleh gateway. msg.value / token transfer utk fraudBond + premi diurus Vault dulu.
    function mintCertificate(
        address to,
        uint256 entryId,
        uint256 declaredValue,
        bool insurable,
        string calldata tokenURI_
    ) external returns (uint256 certId);

    function certData(uint256 certId) external view returns (CertData memory);
    /// Coverage aktif = insurable && !revoked && now dalam [coverageStart, coverageEnd]
    function isCoverageActive(uint256 certId) external view returns (bool);
    /// dipanggil ChallengeManager
    function markRevoked(uint256 certId) external;
    function incrementSurvived(uint256 certId) external;

    event CertificateMinted(uint256 indexed certId, uint256 indexed entryId, address indexed to, uint256 declaredValue);
}

/// ---------- CachetVault (bond, premi, payout) ----------
interface ICachetVault {
    /// Dipanggil gateway saat mint: tarik fraudBond + premi (ERC-20 payToken, approve dulu)
    function collectOnMint(uint256 certId, address payer, uint256 fraudBond, uint256 premium) external;
    /// Dipanggil ChallengeManager:
    function collectChallengeBond(uint256 challengeId, address challenger, uint256 amount) external;
    /// payout klaim ke pemegang cert saat ini + bounty ke penantang; slash fraud bond kreator
    function settleChallengeWon(uint256 certId, uint256 challengeId, address certHolder, address challenger) external;
    /// challenge gagal: slash bond penantang (50% holder, 50% vault)
    function settleChallengeLost(uint256 challengeId, address certHolder) external;

    function payToken() external view returns (address);
    function balanceOfVault() external view returns (uint256);
}

/// ---------- ChallengeManager ----------
interface IChallengeManager {
    enum Status { None, Open, UpheldChallengerWon, DismissedChallengerLost }

    /// Siapa pun boleh menggugat cert aktif. evidenceURI = bukti admissible
    /// (timestamp on-chain / snapshot web-archive / C2PA capture) di IPFS/URL.
    function challenge(uint256 certId, string calldata evidenceURI) external returns (uint256 challengeId);

    /// MVP: hanya resolver (admin) yang memutus, SETELAH liveness window (48 jam)
    /// kecuali kedua pihak setuju lebih cepat. Roadmap: optimistic oracle.
    function resolve(uint256 challengeId, bool challengerWins, string calldata rulingURI) external;

    function getChallenge(uint256 challengeId) external view returns (
        uint256 certId, address challenger, uint64 openedAt, Status status, string memory evidenceURI
    );

    event ChallengeOpened(uint256 indexed challengeId, uint256 indexed certId, address indexed challenger);
    event ChallengeResolved(uint256 indexed challengeId, Status status);
}
```

**Aturan wiring (B):** `mintCertificate`, `register`, `collectOnMint` = `onlyGateway` (satu address, di-set saat deploy, bisa diganti owner). `markRevoked`/`incrementSurvived`/`settle*` = `onlyChallengeManager`. `resolve` = `onlyResolver`. `payToken` = ERC-20 mock USDT di testnet (B deploy sendiri `MockUSDT` 6 desimal dengan faucet `mint(address,uint256)` publik).

### 3.2 JSON schema — Originality Profile (output `verify`; A produksi, B tampilkan di cert page bila mau)

```jsonc
{
  "version": "1.0",
  "request_id": "uuid",
  "asset_sha256": "0x…",                    // hash file mentah
  "verdict": "ORIGINAL | NEAR_DUP | GRAY_ZONE",
  "first_seen": {
    "is_first": true,
    "nearest_entry_id": 123,                 // null jika registry kosong utk kueri ini
    "min_hamming": 87,                       // terkecil dari 4 hash
    "hashes_matched": 0                      // berapa dari 4 hash yang ≤25
  },
  "distinctiveness": {
    "score": 0.87,                           // 1 - max cosine sim, advisory
    "nearest_cosine": 0.13,
    "label": "DISTINCTIVE | DERIVATIVE | GENERIC"   // >0.7 / 0.3–0.7 / <0.3
  },
  "ai_declaration": {
    "c2pa_present": false,
    "synthid_checked": false,                // MVP: false selalu (tidak dicek); jujur
    "notes": "advisory only"
  },
  "insurable": true,                         // false utk NEAR_DUP & GRAY_ZONE
  "premium_quote": { "declared_value": 50.0, "premium": 1.0, "fraud_bond": 5.0, "currency": "USDT" },
  "phashes": ["0x…","0x…","0x…","0x…"],      // utk registrasi on-chain
  "embedding_commit": "0x…",
  "signed": {
    "signer": "0xGATEWAY",
    "signature": "0x…",                      // EIP-712 atas (asset_sha256, verdict, phashes, timestamp)
    "timestamp": 1753000000
  }
}
```

### 3.3 Endpoint gateway (A) — dipakai untuk listing ASP & dipanggil agent

| Tool MCP / REST | Method | Bayar | In | Out |
|---|---|---|---|---|
| `verify_originality` / `POST /v1/verify` | x402 0.02 | image (base64/URL) + optional declared_value | Originality Profile (§3.2) |
| `commit_work` / `POST /v1/commit` | x402 0.01 | commit_hash (client-side dihitung; server sediakan helper rumus) | tx hash + timestamp |
| `register_and_mint` / `POST /v1/mint` | x402 0.5 + premi | image + creator_address + declared_value + optional reveal(salt) | cert_id, tx hash, cert page URL, Originality Profile |
| `get_certificate` / `GET /v1/cert/:id` | gratis | cert id | CertData + umur + challenges survived + status coverage |
| `challenge_certificate` / `POST /v1/challenge` | on-chain bond | cert_id + evidence URI | challenge_id + instruksi bond |
| `watch_subscribe` / `POST /v1/watch` | x402 0.1/30hari | cert_id + webhook/email | subscription id |

Semua endpoint idempotent bila diberi `request_id` sama. Error format: `{ "error": { "code", "message" } }`.

### 3.4 Artefak yang dipertukarkan (satu-satunya dependency antar orang)

| Artefak | Dari | Ke | Kapan |
|---|---|---|---|
| Dokumen ini (§3 disepakati) | bersama | bersama | **Hari-1, sebelum coding** |
| `abi/*.json` + `addresses.testnet.json` + address `MockUSDT` | B | A | Hari-3 malam (deploy testnet) |
| Address signer gateway (utk `onlyGateway`) | A | B | Hari-1 |
| URL gateway publik + contoh profile JSON | A | B (utk cert page, opsional) | Hari-4 |

---

## 4. WORKSTREAM A — Off-chain (Person: **Dien** + AI-nya)

> Boleh mereferensikan repo Veritas milik Dien (`Veritas-1` untuk pHash, `Veritas-UHI9/oracle` untuk pola EIP-712). Semua reuse berhenti di sini — output A tidak mensyaratkan B paham asal-usulnya.

**Repo baru:** `cachet/` — monorepo folder `engine/` (Python), `gateway/` (TS), `watch/` (TS), `scripts/`.

### A1 — Originality Engine (Python FastAPI) — Hari 1–2

Fungsi: hashing + embedding + index + kueri. **Tanpa state chain** (murni konten).

Langkah:
1. Scaffold FastAPI + endpoints internal: `POST /hash` (gambar → 4 pHash + sha256), `POST /query` (gambar → nearest neighbors pHash & embedding), `POST /index` (tambah entri: phashes, embedding, entry_id, meta).
2. **Ensemble pHash ×4** pakai `imagehash`: `phash`, `average_hash`, `dhash`, `whash` — masing-masing 16×16 → 256 bit. Normalisasi gambar dulu (RGB, resize sisi panjang 512, strip alpha).
3. **Embedding**: `open_clip` ViT-B/32 (cukup & cepat CPU) → vektor 512-d, L2-normalized. `embedding_commit = keccak256(vector float32 bytes)`.
4. **Index**: FAISS (`IndexFlatIP` untuk cosine) + tabel SQLite (`entries(entry_id, phash0..3 BLOB, sha256, source, uri, created_at)`). Kueri pHash = linear scan Hamming (cukup untuk ≤100k entri; XOR + popcount di numpy).
5. **Logika verdict** (persis §1.3): `NEAR_DUP` bila ≥2 hash Hamming ≤25; else `GRAY_ZONE` bila max cosine ∈ [0.90, 0.97]; else `ORIGINAL`. Distinctiveness = 1 − max cosine.
6. **C2PA reader**: coba parse manifest C2PA dari file (pakai `c2pa-python`; kalau library rewel, cukup deteksi keberadaan JUMBF box dan laporkan `c2pa_present` — jujur di README).
7. Unit test: 10+ kasus (identik, resize, crop 10%, JPEG q30, grayscale → wajib NEAR_DUP; gambar beda → ORIGINAL; style-mirip → GRAY_ZONE fixture).

**Acceptance:** `pytest` hijau; `curl /query` dengan gambar yang sudah di-index versi resize-nya → NEAR_DUP dengan min_hamming ≤ 25.

### A2 — Pre-seed corpus + demo fixture — Hari 2 (paralel A1 akhir)

1. Script `scripts/preseed.py`: ingest **≥5.000 gambar publik** (mis. beberapa koleksi NFT populer via API marketplace/IPFS + subset Wikimedia). Simpan **hanya hash + embedding + URI sumber** (bukan file).
2. **Demo fixture (PENTING untuk video):** masukkan 3–5 karya "korban" yang dikenal → siapkan salinan modifikasi (resize/crop/recolor) di folder `demo/` → verifikasi tertangkap NEAR_DUP. Ini adegan *the catch* di demo.
3. Catat cakupan korpus (jumlah, sumber) → untuk disclosure "dicek vs korpus kami".

**Acceptance:** registry berisi ≥5k entri; semua fixture demo tertangkap; waktu kueri < 2 detik.

### A3 — Gateway (Node/TS Fastify): x402 + MCP + EIP-712 + tx submitter — Hari 2–3

1. Scaffold Fastify + `@modelcontextprotocol/sdk` (expose tools §3.3) + REST paralel.
2. **x402**: integrasi OKX Payment SDK / onchainos (`okx-agent-payments-protocol`) sebagai middleware: endpoint berbayar balas `402` + payment requirements; verifikasi settlement sebelum eksekusi. (Dev mode: env `X402_BYPASS=1` untuk testing lokal.)
3. **Signer EIP-712**: domain `Cachet-v1`, type `Verdict(bytes32 assetSha256,uint8 verdict,bytes32 phash0,uint64 timestamp)`. Kunci dari env (wallet gateway; address ini yang di-share ke B Hari-1).
4. **Alur `register_and_mint`:** verify dulu (internal) → tolak `NEAR_DUP` → hitung premi → (on-chain, via viem): `payToken.approve` → `Vault.collectOnMint` → `Registry.register` → `Certificate.mintCertificate` → balas cert_id + link cert page. Sebelum ABI B ada: pakai **stub in-memory chain** di belakang interface `ChainClient` (swap ke viem saat integrasi — desain ini yang membuat A tak menunggu B).
5. **Commit-reveal helper**: endpoint `commit_work` menerima `commit_hash` jadi (dokumentasikan rumus `keccak256(phash0 ‖ salt ‖ creator)`), submit ke Registry; `register_and_mint` menerima `salt` opsional untuk reveal.
6. Rate limit + max upload 10 MB + logging request_id.

**Acceptance:** e2e lokal (engine + gateway + stub chain): verify → mint → get_certificate jalan; bayar x402 di-enforce (tanpa bayar → 402).

### A4 — Watch worker — Hari 3–4

1. Cron (node-cron, tiap 6 jam + trigger manual): untuk tiap subscription aktif → kueri engine: adakah **entri baru** (entry_id > last_checked) yang NEAR_DUP terhadap aset yang diawasi?
2. Match → kirim webhook/email alert + generate **draft challenge** (evidence = entri lama + timestamp) + simpan di dashboard-lite (JSON file/SQLite cukup).
3. Simpan state `last_checked_entry_id` per subscription.

**Acceptance:** simulasi — subscribe aset X, register salinan X′ → alert terkirim < 1 siklus cron.

### A5 — Integrasi chain nyata + ASP okx.ai — Hari 4–5

1. Terima `abi/` + `addresses.testnet.json` dari B → implement `ChainClient` viem (chain X Layer testnet, chainId 195) → ganti stub → e2e ulang di testnet.
2. Deploy gateway + engine ke host publik HTTPS (Railway/Fly/VPS; engine & gateway satu mesin cukup).
3. Registrasi ASP di okx.ai via skill `okx-ai` (Agentic Wallet Dien sudah ada). Detail listing → lihat `delivery_implementation_plan.md`.

**Acceptance:** panggilan `verify_originality` dari klien MCP eksternal (Claude Code) dengan pembayaran x402 sungguhan → profile sah; `register_and_mint` menghasilkan NFT terlihat di explorer X Layer testnet.

---

## 5. WORKSTREAM B — On-chain + Certificate Page (Person: **teman** + AI-nya)

> **Self-contained.** Semua yang dibutuhkan ada di dokumen ini (terutama §3.1). Tidak perlu tahu apa pun tentang Veritas/pHash internals — dari sudut pandang kontrak, `phashes` hanyalah `bytes32[4]` yang disimpan.

**Repo baru:** `cachet-contracts/` (Foundry) + `cachet-cert-page/` (site statis).

### B1 — Setup Foundry + MockUSDT — Hari 1

1. `forge init`; solc 0.8.24; OpenZeppelin (`ERC721`, `Ownable`, `SafeERC20`).
2. `MockUSDT.sol`: ERC-20, 6 desimal, fungsi `faucet(address to, uint256 amt)` publik (testnet only).
3. Konfigurasi X Layer testnet: RPC `https://testrpc.xlayer.tech`, chainId **195**, explorer `https://www.okx.com/web3/explorer/xlayer-test`. Gas token OKB testnet dari faucet OKX.

**Acceptance:** `forge test` template jalan; MockUSDT ter-deploy di testnet + faucet berfungsi.

### B2 — Empat kontrak inti — Hari 1–3 (bagian terbesar)

Implementasikan **persis** interface §3.1, ditambah aturan berikut:

1. **CachetRegistry**: `commit()` terbuka untuk siapa pun (murah, hanya simpan `commitHash → timestamp`, tolak overwrite). `register()` `onlyGateway`; bila `revealedCommit != 0x0`, wajib `commitTimestamp[revealedCommit] > 0` dan simpan `commitAt` = timestamp tsb (kontrak TIDAK memverifikasi isi commitment — verifikasi rumus dilakukan gateway; catat trade-off ini di NatSpec).
2. **CachetCertificate**: ERC-721 standar (transfer = coverage pindah otomatis karena data coverage keyed by tokenId — tak perlu logic tambahan; **jangan** soulbound). Konstanta: `WAITING_PERIOD = 72 hours`, `COVERAGE_TERM = 365 days`, `MAX_DECLARED_VALUE = 100e6`. `mintCertificate` revert bila `declaredValue > MAX_DECLARED_VALUE`.
3. **CachetVault**: pegang MockUSDT. `collectOnMint` = `transferFrom(payer)` fraud bond + premi, book-keep per certId. `settleChallengeWon`: bayar `declaredValue` (atau saldo vault jika kurang — `min()`, dan emit event `PartialPayout` — jujur soal plafon bootstrap) ke `certHolder`… **koreksi**: payout ke **pemegang saat resolve** (ambil `ownerOf(certId)` saat itu, bukan parameter bebas — parameter `certHolder` tetap ada untuk event tapi validasi `require(certHolder == ownerOf)`); bounty penantang = fraud bond certId + 50% premi certId. `settleChallengeLost`: bond penantang → 50% `ownerOf(certId)`, 50% tinggal di vault.
4. **ChallengeManager**: `challenge()` siapa pun, syarat `isCoverageActive(certId)` ATAU cert dalam masa hidup (boleh gugat cert tak-insurable untuk mencabut sertifikatnya — payout 0, tapi `revoked` tetap di-set), tarik challenge bond via Vault, status `Open`. `resolve()` `onlyResolver` + `require(block.timestamp >= openedAt + 48 hours || …)` (MVP: cukup tunggu liveness). Menang → `Certificate.markRevoked` + `Vault.settleChallengeWon`. Kalah → `Certificate.incrementSurvived` + `Vault.settleChallengeLost`.
5. **Deploy script** (`script/Deploy.s.sol`): deploy urut, wire address (`setGateway`, `setChallengeManager`, `setResolver`), tulis `addresses.testnet.json` + export ABI ke `abi/`.

**Test Foundry (minimal 20):** happy path mint→transfer→challenge menang (payout ke **pembeli**, bukan kreator — INI test terpenting, buktikan "coverage transferable"); challenge kalah → slash + survived++; waiting period menolak resolve payout dini; declared value > plafon revert; non-gateway tak bisa mint/register; commit → register dengan commitAt benar; double-commit revert; vault kurang saldo → partial payout + event.

**Acceptance:** `forge test` hijau semua; deploy testnet sukses; `abi/` + `addresses.testnet.json` diserahkan ke A **Hari-3 malam**.

### B3 — Certificate Page (site statis) — Hari 3–4

Bukti publik yang bisa dicek siapa pun **tanpa percaya Cachet** — baca chain langsung.

1. Vite + TS + viem (read-only, tanpa wallet connect). Route `/cert/:id`.
2. Tampilkan: gambar aset (dari tokenURI), status badge (**ACTIVE / NOT INSURABLE / REVOKED / EXPIRED**), declared value, coverage window, **umur sertifikat** (hari sejak mint), **challenges survived**, riwayat event challenge (dari log), address kreator & pemegang kini, link explorer, entry registry (phash0 sebagai "fingerprint" hex dipendekkan).
3. Copy jujur di footer: *"First-seen di registry Cachet per timestamp T — bukan klaim keaslian. Coverage mengikuti pemegang NFT."* Hindari kata "insurance" (pakai *guarantee / collateralized certificate*).
4. Deploy ke Vercel/Netlify. URL pattern di-share ke A (`https://…/cert/:id`) untuk dipakai di response mint.

**Acceptance:** buka `/cert/1` untuk cert hasil test deploy → semua field benar vs explorer; halaman shareable (OG tags).

### B4 — Resolver runbook + skenario demo on-chain — Hari 4–5

1. Script `script/DemoFlow.s.sol` / makefile: satu perintah menjalankan skenario demo penuh di testnet (mint cert → transfer ke wallet "pembeli" → buka challenge → resolve menang → payout ke pembeli) untuk direkam di video.
2. Runbook singkat `RESOLVER.md`: cara resolver menilai bukti admissible (checklist 3 kelas bukti dari ideation brief) + perintah `cast send … resolve(...)`.

**Acceptance:** skenario demo jalan mulus 2× berturut-turut dengan wallet segar.

---

## 6. INTEGRASI (Hari 4–5 — satu-satunya fase kerja bersama)

Checklist urut (perkiraan setengah hari kerja bersama):

1. B serahkan `abi/` + `addresses.testnet.json` + address MockUSDT (faucet).
2. A: swap stub → viem `ChainClient`; isi env (`RPC_URL`, `CHAIN_ID=195`, addresses, gateway private key); faucet OKB + MockUSDT ke wallet gateway.
3. B: `setGateway(addressGatewayA)` di Registry/Certificate/Vault.
4. **Smoke test bersama (urutan Golden Path):**
   - [ ] `verify` gambar baru → ORIGINAL
   - [ ] `verify` fixture salinan → NEAR_DUP (the catch)
   - [ ] `commit_work` → tx sukses, timestamp terekam
   - [ ] `register_and_mint` (dengan reveal) → NFT ada, cert page tampil benar, `commitAt` < `mintedAt`
   - [ ] transfer NFT ke wallet kedua → cert page tunjukkan pemegang baru, coverage tetap aktif
   - [ ] `challenge` + resolve (menang) → payout masuk **wallet kedua**, cert page = REVOKED
   - [ ] challenge cert lain + resolve (kalah) → survived = 1, bond penantang ter-slash
   - [ ] Watch: register salinan baru → alert
   - [ ] semua panggilan berbayar menolak tanpa x402
5. Rekam ulang skenario di atas dalam kondisi bersih → bahan video demo.

**Definition of Done MVP:** seluruh checklist di atas hijau di X Layer testnet dari klien eksternal.

---

## 7. TIMELINE (deadline submit: 27 Jul 22:59 UTC; target ASP live: 25 Jul)

| Hari | Person A (Dien) | Person B (teman) |
|---|---|---|
| **H1 (21/7)** | Sepakati §3 · scaffold engine (A1) · kirim address signer ke B | Sepakati §3 · Foundry setup + MockUSDT (B1) · mulai kontrak (B2) |
| **H2 (22/7)** | Selesaikan A1 + pre-seed & fixture (A2) · mulai gateway (A3) | Lanjut B2 (4 kontrak + test) |
| **H3 (23/7)** | Selesaikan gateway + stub e2e (A3) · mulai Watch (A4) | Selesaikan B2 · deploy testnet · **serahkan ABI+addresses malam ini** · mulai cert page (B3) |
| **H4 (24/7)** | Integrasi viem (A5) · selesaikan Watch | Selesaikan cert page (B3) · demo script (B4) |
| **H5 (25/7)** | **Smoke test bersama (§6)** · deploy publik · **daftar ASP okx.ai → antre review ≤24 jam** | Smoke test bersama · runbook resolver · polish cert page |
| **H6 (26/7)** | ASP live → rekam demo, post X (lihat delivery plan) | Bantu rekaman skenario on-chain · standby fix |
| **H7 (27/7)** | Google Form sebelum 22:59 UTC + buffer | standby |

**Aturan potong-scope kalau telat (urutan buang):** 1) Watch otomatis → jadi tombol "re-scan now" manual; 2) commit-reveal → dokumentasikan saja (kontraknya tetap ada, UI-nya belakangan); 3) C2PA reader → laporkan `not_checked`. **Golden Path 4 langkah TIDAK BOLEH dipotong.**

---

## 8. TECH STACK & ENV

| Komponen | Teknologi | Env vars kunci |
|---|---|---|
| Engine | Python 3.11, FastAPI, imagehash, Pillow, open_clip_torch (CPU), faiss-cpu, sqlite3 | `ENGINE_PORT`, `INDEX_PATH` |
| Gateway | Node 20, TS, Fastify, viem, @modelcontextprotocol/sdk, OKX Payment SDK (x402) | `GATEWAY_PK`, `RPC_URL=https://testrpc.xlayer.tech`, `CHAIN_ID=195`, `ENGINE_URL`, `X402_*`, `X402_BYPASS` (dev) |
| Watch | Node 20, node-cron | `CRON_SCHEDULE`, `WEBHOOK_*` |
| Kontrak | Solidity 0.8.24, Foundry, OpenZeppelin 5 | `DEPLOYER_PK`, `RESOLVER_ADDR`, `GATEWAY_ADDR` |
| Cert page | Vite, TS, viem (read-only) | `VITE_RPC_URL`, `VITE_ADDRESSES` |
| Hosting | Railway/Fly (A) · Vercel/Netlify (B) | |

---

## 9. INVARIANT KEAMANAN (wajib di-test / di-review sebelum demo)

1. Payout **selalu** ke `ownerOf(certId)` saat resolve — bukan ke kreator, bukan ke parameter bebas.
2. Tidak ada jalur mint/register selain gateway; tidak ada jalur revoked/payout selain ChallengeManager.
3. Vault tak pernah transfer melebihi saldonya (partial payout + event, bukan revert yang mengunci klaim).
4. Waiting period & coverage window dicek on-chain (bukan hanya di gateway).
5. Double-resolve challenge revert; double-commit revert; re-register phash identik oleh gateway = ditolak di gateway (on-chain tidak dedup — dicatat di NatSpec).
6. Private key gateway & resolver terpisah; keduanya bukan deployer/owner yang sama di produksi demo.
7. Semua klaim di UI/README mengikuti bahasa jujur: "first-seen di registry", "guarantee/bond" (bukan "insurance"), "advisory" untuk tier embedding.

---

## 10. OPEN FLAGS (keputusan yang masih bisa berubah — default sudah dipilih)

| Flag | Default MVP | Alternatif | Pemutus |
|---|---|---|---|
| Testnet vs mainnet X Layer utk demo final | **Testnet (195)** | Mainnet (196) bila semua hijau H5 & ada OKB | Dien, H5 |
| Payment token demo on-chain | MockUSDT (faucet) | USDT asli di mainnet | mengikuti flag di atas |
| Embedding model | open_clip ViT-B/32 | DINOv2 (lebih berat) | A, bebas selama §3.2 tetap |
| Hosting gateway | Railway | Fly/VPS | A |
| Harga listing x402 | tabel §1.3 | boleh disesuaikan saat listing | Dien saat registrasi ASP |

---

*Dokumen delivery (registrasi ASP, video demo, README, X post, Google Form) → `delivery_implementation_plan.md` di folder yang sama.*
