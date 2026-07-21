# CACHET — Delivery Implementation Plan v1

> **Basis:** `cachet_idea_v2.md` (Ideation v2.1 FINAL) + `technical_implementation_plan.md` (folder yang sama).
> **Untuk siapa:** Person A (Dien) & Person B (Wangsit) + AI agent masing-masing. Dokumen ini mengatur **semua yang bukan kode**: pendaftaran ASP, go-live, video demo, README, posting X, Google Form — sampai submission selesai.
>
> **Prinsip #1: buffer review.** Listing ASP harus **lolos review internal OKX (≤24 jam) dan LIVE** untuk eligible. Risiko terbesar bukan kode, tapi antrean review. Maka: **submit listing paling lambat 25 Jul pagi WIB** — bukan mendekati deadline.
>
> **Prinsip #2: Golden Path adalah satu-satunya cerita.** Di SEMUA kanal (listing, video, README, X): hanya 4 langkah — **verify → certify → coverage ikut pembeli → challenge**. Fitur lain (Watch, commit-reveal, seasoning, rev-share) = satu kalimat, hanya bila ditanya/di bagian "advanced".

---

## 1. GARIS WAKTU & DEADLINE KERAS

| Waktu (WIB) | Milestone | Owner |
|---|---|---|
| **H5 — 25 Jul pagi** | Smoke test §6 tech-plan hijau → **submit listing ASP di okx.ai** (mulai antrean review ≤24 jam) | A |
| 25 Jul | Cert page final + skenario demo on-chain siap direkam | B |
| **H6 — 26 Jul** | ASP **LIVE** dikonfirmasi → rekam & edit video ≤90s → **post X dengan #OKXAI** | A (rekam), B (bahan on-chain) |
| **H7 — 27 Jul, target siang WIB** | **Google Form** terisi & tersubmit (deadline resmi 27 Jul 22:59 UTC = 28 Jul 05:59 WIB — JANGAN mepet ke situ) | A |
| Sesudahnya s/d 3 Agu | Social Buzz (amplifikasi engagement) | A + B |

**4 syarat submission resmi (semua wajib):**
1. ✅ Build ASP use-case nyata
2. ✅ Listing di okx.ai **lolos review & LIVE**
3. ✅ Post X memakai **#OKXAI** + demo **≤90 detik**
4. ✅ Google Form sebelum deadline (detail ASP + link post X)

**Contingency:**
- **Review ditolak** → perbaiki sesuai feedback email, resubmit hari yang sama; karena buffer 2 hari, masih ada 1 siklus review lagi.
- **Kontrak belum stabil H5** → jalankan aturan potong-scope §7 tech-plan; listing tetap disubmit dengan scope terpotong (Golden Path minimal), JANGAN menunda listing demi fitur.
- **x402 bermasalah di produksi** → turunkan harga verify jadi free sementara (listing free tetap eligible), perbaiki setelah live.

---

## 2. PENDAFTARAN ASP & GO-LIVE DI OKX.AI (Owner: A)

### 2.1 Prasyarat (sudah ada)
- OKX Onchain OS CLI terpasang; Agentic Wallet Dien aktif (login email; EVM address siap; key di TEE).
- Skill `okx-ai` (agent identity) tersedia di Claude Code.

### 2.2 Langkah registrasi
1. Pastikan gateway publik HTTPS hidup + endpoint §3.3 tech-plan responsif.
2. Via Claude Code: jalankan skill `okx-ai` → **"register as ASP"** → isi identitas agent (ERC-8004) → daftarkan endpoint A2MCP + harga x402.
3. Submit listing → antre review ≤24 jam → pantau email.
4. Setelah live: **beli layanan sendiri 1×** dari wallet lain (sanity check pembeli sungguhan) sebelum merekam video.

### 2.3 Copy listing (siap tempel — bahasa memimpin deteksi + jaminan; JANGAN pakai kata "insurance")

- **Nama:** `Cachet — Verified-Original Minting`
- **One-liner:** *Proof it's first. Money if it's not.*
- **Deskripsi:**
  > Cachet checks any image against an on-chain registry before you mint: exact/near-duplicate detection (deterministic, re-runnable by anyone) plus a distinctiveness score (advisory). Clean results can be minted with a **First-Seen Certificate** — an on-chain, timestamped, **collateralized guarantee** that travels with the asset: if an older copy is ever proven, **whoever holds the asset** gets paid the declared value. Anyone can challenge a certificate with admissible evidence and earn a bounty. Built for minting/branding agents and creators. Pay-per-call via x402.
- **Kategori/track listing:** Software Utility (primer), relevan juga Art Creation.
- **Harga (x402, USDT):** `verify` 0.02 · `commit` 0.01 · `register_and_mint` 0.5 + 2% declared value · `watch` 0.1/30 hari · `get_certificate` gratis.
- **Disclosure jujur (taruh di bagian akhir deskripsi/docs):** guarantee = klaim *first-seen dalam registry Cachet per timestamp T* — bukan klaim keaslian/bukan-AI; tier embedding bersifat advisory; adjudikasi challenge MVP dilakukan resolver Cachet dengan jendela publik 48 jam (roadmap: optimistic oracle); coverage berplafon selama bootstrap.

---

## 3. VIDEO DEMO ≤90 DETIK (Owner rekaman: A; bahan on-chain: B)

### 3.1 Skrip 4-beat (= Golden Path; total 85 detik, sisakan margin)

| Beat | Detik | Adegan (layar) | Narasi (inti) |
|---|---|---|---|
| **1. Hook** | 0–12 | Statistik singkat konten AI membanjir → muncul tagline | "Most new content is AI-generated. When everything can be copied in seconds, how do you prove yours came first? **Cachet: proof it's first — money if it's not.**" |
| **2. The Catch** | 12–35 | Klien MCP (Claude Code) memanggil `verify_originality` (bayar x402 terlihat) atas **salinan termodifikasi** dari karya yang sudah terdaftar → Originality Profile menangkap **NEAR_DUP** (tunjukkan hamming & nearest match berdampingan) | "Any agent can call Cachet before minting. This 'new' artwork? Caught — a near-duplicate of a registered piece, deterministically, not an AI guess." |
| **3. Certify + Guarantee moves** | 35–65 | Gambar orisinal → `register_and_mint` → **cert page** terbuka (timestamp, declared value, badge ACTIVE) → **transfer NFT ke wallet pembeli** → cert page menunjukkan pemegang baru, coverage tetap aktif | "Clean work gets a First-Seen Certificate — on-chain, collateralized. And here's the key: when the asset is sold, **the guarantee travels with it**. The buyer is protected, not just the creator." |
| **4. Challenge payoff** | 65–85 | `challenge` dengan bukti → resolve → **payout masuk ke wallet PEMBELI** di explorer → tutup dengan URL listing okx.ai + #OKXAI | "Anyone can challenge with evidence and earn a bounty. If an older copy is proven — the current holder gets paid. Live now on okx.ai." |

### 3.2 Checklist layar (yang juri harus LIHAT, bukan dengar)
- [ ] Pembayaran x402 sungguhan terlihat minimal 1× (quote + settle)
- [ ] Verdict NEAR_DUP berdampingan dengan gambar asli vs salinan (bukti "the catch" nyata)
- [ ] Cert page publik + tx hash di explorer X Layer (bukti on-chain nyata)
- [ ] Transfer NFT → payout ke **pemegang baru** (ini pembeda #1; jangan sampai terpotong)
- [ ] URL listing okx.ai di frame terakhir ≥3 detik

### 3.3 Larangan
- ❌ Menyebut "insurance", "100% original", "AI detector", "trustless adjudication"
- ❌ Menunjukkan fitur di luar Golden Path (Watch dkk. cukup 1 bullet di README)
- ❌ Footage > 90 detik (auto-gugur syarat)

### 3.4 Produksi
Rekam layar 1080p (CleanShot/OBS), voice-over atau caption tegas, potong mati semua loading (jump-cut), musik lembut opsional. **Kecuali jeda mekanisme:** masa tunggu coverage dan jendela liveness (total ~40 detik di setelan demo) **DIPERCEPAT (time-lapse), bukan dipotong** — keduanya adalah mekanisme produk yang harus terlihat bekerja. Memotongnya menyembunyikan; mempercepatnya menunjukkan. Parameter demo tercatat publik di explorer lewat event `ParamChanged`. B menyiapkan **skenario on-chain siap-jalan** (`DemoFlow` script) supaya rekaman sekali take. Simpan master + versi ≤90s.

---

## 4. README REPO (Owner: A menulis; B mengisi bagian kontrak)

Struktur wajib:

1. **Judul + tagline + 3 badge** (okx.ai listing · X Layer testnet · demo video)
2. **What it does** — Golden Path 4 langkah, 4 kalimat.
3. **Why it's different** — tabel singkat vs provenance tools (provenance mencatat asal; Cachet mendeteksi salinan + menaruh jaminan yang ikut pembeli).
4. **Architecture** — diagram §2 tech-plan + link cert page & explorer.
5. **Try it** — cara memanggil dari klien MCP + contoh curl + harga x402.
6. **Contracts** — tabel address (B) + cara jalankan `forge test`.
7. **⚠️ Honesty / limitations section (WAJIB, ini fitur bukan aib):** first-seen ≠ keaslian; registry-scoped (sebut ukuran korpus); tier embedding advisory; resolver MVP tersentralisasi + jendela publik; plafon coverage bootstrap; roadmap (optimistic oracle, staking pool, rev-share, ERC-8004 reputation, seasoning penuh).
8. **Team & links** — X post, listing, video.

---

## 5. POST X + SOCIAL BUZZ (Owner: A; B amplifikasi)

### 5.1 Post utama (syarat submission — WAJIB #OKXAI + video ≤90s)

> Most of the internet is now AI-generated. Proving your work came FIRST is the new scarcity.
>
> Meet **Cachet** — verified-original minting for the agent economy, live on @OKX okx.ai:
> ✅ deterministic copy-detection before mint
> ✅ on-chain First-Seen Certificate
> ✅ collateralized guarantee that **travels with the buyer**
> ✅ open challenge market with bounties
>
> Proof it's first. Money if it's not. 🎥⬇️ #OKXAI
> [video ≤90s] · [link listing okx.ai]

### 5.2 Social Buzz (track $10K, 10×$1K — buah rendah, kejar paralel)
- Thread lanjutan (hari berikutnya): "How we caught a copymint live" — 3 screenshot the-catch; angle **anti-AI-slop** (tema panas).
- 1 post teknis dari akun B (angle builder: "coverage yang ikut NFT — kenapa belum ada yang bikin ini").
- Balas komentar cepat; tag akun terkait (OKX ecosystem) tanpa spam; jangan beli engagement.
- Jadwal: 26 Jul (post utama) → 27–31 Jul (2–3 follow-up) → jelang pengumuman 3 Agu (recap).

---

## 6. GOOGLE FORM (Owner: A) — checklist isian

Siapkan draft jawaban H6 malam supaya H7 tinggal submit:

- [ ] Nama ASP: Cachet — Verified-Original Minting
- [ ] Link listing okx.ai (status LIVE — screenshot bukti disimpan)
- [ ] Link post X (#OKXAI, video ≤90s)
- [ ] Deskripsi singkat (pakai copy §2.3, ≤ batas karakter form)
- [ ] Track yang dibidik: Best Product + Software Utility (+ Artistic bila form mengizinkan multi)
- [ ] Link repo + README + cert page + explorer
- [ ] Kontak (email Agentic Wallet Dien)
- [ ] Screenshot konfirmasi submit form disimpan

---

## 7. KONSISTENSI PESAN PER-KANAL (tabel rujukan cepat)

| Kanal | Pesan inti | Yang TIDAK disebut |
|---|---|---|
| Listing okx.ai | deteksi salinan + First-Seen Certificate + guarantee ikut pemegang, pay-per-call | "insurance", roadmap panjang |
| Video ≤90s | Golden Path 4 beat, the-catch nyata, payout ke pembeli | fitur non-Golden-Path |
| README | Golden Path + honesty section + cara pakai | overclaim keaslian |
| X | anti-AI-slop + tagline + video | jargon teknis dalam |
| Q&A juri | jawaban FAQ dari `cachet_idea_v2.md` §9 (17 jawaban siap) | improvisasi klaim baru |

**Satu kalimat yang sama di semua kanal:** *"The only mint layer that proves your content is first — and pays whoever holds it if it's not."*

---

## 8. PEMBAGIAN TANGGUNG JAWAB DELIVERY (ringkas)

| Deliverable | Owner | Deadline |
|---|---|---|
| Listing ASP live | **A** | submit 25 Jul pagi |
| Cert page final + skenario demo on-chain | **B** | 25 Jul |
| Video ≤90s | **A** (B menyiapkan on-chain take) | 26 Jul |
| README | **A** (+ bagian kontrak oleh B) | 26 Jul |
| Post X #OKXAI | **A** | 26 Jul |
| Google Form | **A** | 27 Jul siang WIB |
| Social Buzz follow-ups | A + B | 27 Jul – 3 Agu |
