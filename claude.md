# CACHET — instruksi untuk AI coding agent

Proyek ini dikerjakan **2 orang, 2 AI agent, satu monorepo**. Aturan di file ini
mencegah dua agent saling menimpa pekerjaan. **Baca sampai habis sebelum menulis kode.**

Rencana lengkap: `docs/technical_implementation_plan.md` (spec teknis, §3 interface
freeze, §11 pembagian tugas) dan `docs/delivery_implementation_plan.md` (listing ASP,
video, README, X post).

---

## 1. Tentukan dulu: kamu agent siapa?

Sebelum mengedit apa pun, pastikan kamu tahu kamu bekerja untuk **A** atau **B**.
Kalau belum jelas dari percakapan — **tanya, jangan menebak**.

| | **PERSON A — Dien** ("Off-chain Brain") | **PERSON B — Wangsit** ("On-chain & Proof Page") |
|---|---|---|
| Stack | Python (engine) + Node/TS (gateway, watch) | Solidity/Foundry + Vite/viem |
| Boleh tulis | `services/engine/` `services/watch/` `apps/server/` `apps/mcp-server/` `scripts/` | `contracts/` `apps/web/` |
| Tugas | A1 Engine · A2 Pre-seed · A3 Gateway+x402 · A4 Watch · A5 Integrasi+ASP (§4) | B1 Foundry+MockUSDT · B2 4 kontrak+test · B3 Cert page · B4 Demo script (§5) |

Padanan nama lama → folder nyata: Engine → `services/engine/` · Gateway → `apps/server/` ·
MCP tools → `apps/mcp-server/` · Watch → `services/watch/` · Kontrak → `contracts/` ·
Certificate page → `apps/web/`.

---

## 2. LARANGAN LINTAS-FOLDER (aturan terpenting di file ini)

**Jangan pernah membuat, mengedit, atau menghapus file di folder milik orang lain** —
sekalipun kelihatan sepele, sekalipun "cuma nambah satu baris", sekalipun itu
mempercepat pekerjaanmu.

Kalau butuh sesuatu dari folder lawan:
1. **Berhenti.** Jangan edit.
2. Sampaikan ke user apa yang dibutuhkan dan dari siapa.
3. Sementara itu pakai **stub** di folder sendiri (lihat §4 di bawah).

Alasannya: dua agent bekerja paralel di repo yang sama tanpa saling melihat. Edit
lintas-folder = konflik git atau kerja orang lain tertimpa diam-diam.

**Membaca** file folder lawan untuk memahami konteks: boleh. **Menulis**: tidak.

---

## 3. Titik temu — HANYA 3, jangan tambah

Semua koordinasi antar-orang lewat tiga artefak ini saja:

1. **`docs/technical_implementation_plan.md` §3** — interface Solidity + JSON schema
   Originality Profile. **Dibekukan H1.** Mau ubah? Tulis 1 baris changelog di §3
   **dulu** (apa + kenapa), minta persetujuan pihak lain, baru ubah kode. Tanpa
   changelog, perubahan tidak berlaku — dan kode yang menyimpang dari §3 akan gagal
   saat integrasi H5.
2. **`packages/contracts-abi/`** — `abi/*.json` + `addresses.testnet.json` + address
   MockUSDT. **B menulis, A hanya membaca.** Diserahkan H3 malam.
3. **Address signer gateway** (A → B, H1, untuk `onlyGateway`) dan **URL pattern cert
   page** (B → A, H4).

Zona bersama yang butuh review pihak lain sebelum merge: `packages/contracts-abi/`,
`docs/`, dan file konfigurasi root (`.env.example`, `tsconfig.base.json`, `.gitignore`,
`claude.md`, `.github/`).

---

## 4. Jangan menunggu pihak lain — pakai stub

Desainnya memang supaya H1–H3 nol blocking dua arah:

- **A tidak menunggu B:** compile interface §3.1 jadi ABI stub sendiri, implement
  `ChainClient` **in-memory** (mint/register/challenge disimulasikan di memori dengan
  state konsisten). Bangun dan test A1–A4 di atas stub ini. Swap ke viem baru di A5.
- **B tidak menunggu A sama sekali:** cert page membaca **langsung dari chain**, tidak
  menyentuh backend A. Butuh contoh Originality Profile untuk tampilan? Pakai fixture
  JSON sesuai §3.2.

Kalau kamu mendapati diri "menunggu pihak lain selesai" — hampir selalu itu tanda
stub-nya belum dibuat.

---

## 5. Git workflow (monorepo — konflik MUNGKIN terjadi)

- **Tidak ada commit langsung ke `main`.** Semua lewat PR.
- **Branch per orang:** `feat/a-*` (A) · `feat/b-*` (B).
- Sebelum buka PR: `git pull --rebase origin main`.
- PR kecil dan sering. Jangan menumpuk seharian.
- `.github/CODEOWNERS` otomatis meminta review pemilik folder.
- **Jangan pernah `git push --force` ke `main`.** Kalau muncul konflik antar-orang,
  berarti pembagian folder dilanggar — hentikan dan cek §11.1, jangan diselesaikan diam-diam.

---

## 6. Environment

**Satu file `.env` di root** untuk seluruh monorepo. Yang di-commit hanya `.env.example`.

Default tiap tool TIDAK menunjuk ke root — konfigurasikan:
- Python: `load_dotenv(find_dotenv())`
- Node/TS: `dotenv.config({ path: resolve(__dirname, '../../.env') })`
- Foundry: `source ../.env` sebelum `forge script`
- Vite: **wajib** `envDir: '../..'` di `vite.config.ts`

**Aturan secret (tidak bisa ditawar):**
- Jangan pernah commit `.env`, private key, atau kredensial. Sebelum push: `git status --ignored`.
- Jangan pernah hardcode address/RPC/key di kode — semua lewat `.env`.
- **Jangan pernah taruh private key di var ber-prefix `VITE_`** — ikut ter-bundle ke
  JavaScript publik.
- Tiga wallet TERPISAH (gateway, deployer, resolver), semuanya baru & testnet-only.

---

## 7. Bahasa jujur (berlaku di kode, komentar, UI, README, commit message)

Produk ini menjual kepercayaan, jadi klaimnya harus tepat. **Jangan pernah menulis:**

| ❌ Jangan | ✅ Pakai |
|---|---|
| "insurance", "asuransi" | "guarantee", "collateralized certificate", "bond" |
| "100% original", "keaslian terjamin" | "first-seen di registry Cachet per timestamp T" |
| "AI detector" | tier embedding = **advisory** |
| "trustless adjudication" | "adjudikasi resolver + jendela liveness publik (MVP)" |

Batasan yang wajib diakui apa adanya: registry = korpus kami, **bukan seluruh internet**;
coverage berplafon 100 USDT selama bootstrap; adjudikasi MVP masih tersentralisasi.

---

## 8. Invariant keamanan (jangan dilanggar, wajib ada test-nya)

1. Payout **selalu** ke `ownerOf(certId)` saat resolve — bukan kreator, bukan parameter bebas.
2. Tidak ada jalur mint/register selain gateway; tidak ada jalur revoke/payout selain ChallengeManager.
3. Vault tak pernah transfer melebihi saldo — partial payout + event, **bukan revert** yang mengunci klaim.
4. Waiting period & coverage window dicek **on-chain**, bukan cuma di gateway.
5. `X402_BYPASS` dan `DEMO_MODE` **wajib 0** di deployment yang dilisting.

Selengkapnya: `docs/technical_implementation_plan.md` §9.

---

## 9. Scope

**Golden Path 4 langkah tidak boleh dipotong:** verify → certify → coverage ikut pembeli
→ challenge. Kalau waktu mepet, urutan buang: (1) Watch otomatis → tombol manual,
(2) commit-reveal → dokumentasi saja, (3) C2PA reader → laporkan `not_checked`.

**Jangan menambah scope** di luar §1.2. Kalau punya ide fitur baru, sampaikan ke user
sebagai saran — jangan langsung implementasikan.
