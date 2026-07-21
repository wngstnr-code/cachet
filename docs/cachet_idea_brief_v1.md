# CACHET — Ideation Brief v1

Originality-Assurance Mint Layer for the Agent Economy — OKX.AI Genesis Hackathon (ASP / Agentic Commerce)

2026-07-21

# CACHET — Ideation Brief v1

**Originality-Assurance Mint Layer** Versi: 1.0-Ideation | Tanggal: 2026-07-21 | Status: Ide tervalidasi (siap masuk fase teknis) **Primary Track:** Software Utility + Best Product (multi-track: + Artistic Excellence, Social Buzz paralel)

> **Ruang lingkup dokumen ini:** ini **DOKUMEN IDE** hasil ideation — memuat problem, positioning, value prop, fitur (level-ide), risiko, FAQ, dan decision log. **TIDAK** memuat arsitektur sistem, pembagian tugas, interface contracts, timeline (→ *Technical Implementation Doc* terpisah), maupun panduan demo video/README (→ *Delivery Implementation Doc* terpisah).
>
> **Catatan penamaan:** "Cachet" (berarti *segel/tanda keaslian & prestise*) adalah nama kerja — dipilih karena persis menggambarkan produk: **segel yang menyatakan "terbukti pertama + berasuransi".** Alternatif: *Priori · Firstmark · Attesta · Prova*. Perlu cek ketersediaan trademark sebelum final.

---

## 1. RINGKASAN EKSEKUTIF

**Cachet adalah layanan (ASP) yang dipanggil agent & kreator saat mereka mencetak konten — untuk membuktikan karyanya "yang pertama" dan menaruh uang di belakang klaim itu.**

Di 2026, **50–64% konten internet baru sudah dihasilkan AI**. Autentisitas jadi langka justru saat konten membanjir — dan yang langka itu bernilai. Tapi tak ada satu pun cara bagi konten yang baru di-mint untuk membuktikan **"aku yang pertama, bukan salinan"** — sambil menanggung risiko kalau ternyata salah.

Cachet bekerja lewat **satu panggilan** (x402/MCP di okx.ai):

1. **Verify** — cek konten terhadap registry on-chain: apakah ada salinan/duplikat? seberapa distinctive vs generik?
2. **Certify & Mint** — terbitkan **sertifikat "First-Seen"** ber-timestamp on-chain, dilekatkan ke aset saat mint.
3. **Guarantee** — sertifikat itu **berasuransi**: kalau kelak terbukti ada salinan yang lebih tua, pemegang **dikompensasi**.
4. **Challenge** — siapa pun boleh menantang sertifikat dengan bukti; penantang yang benar dapat bounty.

Outputnya = **"Content Authenticity Profile"**: *pertama? · distinctive atau derivatif? · deklarasi-AI ada?* — bukan cap biner "AI atau bukan" (yang terbukti tak reliabel), melainkan laporan multi-sinyal yang jujur.

**Satu kalimat untuk juri:** *"The only mint layer that proves your content is first — and pays you if it's not."*

**Cara menjangkaunya:** dipasang sebagai **ASP di okx.ai**, dipanggil via **x402** (stablecoin, pay-per-call) oleh agent generator/minter (PixStudio, Apex10K, XLayer NFT Mint, BrandCanvas, PixelBrief) maupun kreator langsung — tepat di titik konten dibuat.

---

## 2. KENAPA IDE INI (validasi problem, kriteria, benchmark)

### 2.1 Kriteria penilaian (rubrik 8-dimensi hasil riset ASP sukses okx.ai)

Kami mengekstrak pola kemenangan dari ASP paling sukses di okx.ai (rating × jumlah `sold`) menjadi 8 kriteria tertimbang. Skor **tidak dibatasi skala tertutup** — ide yang benar-benar unggul boleh menembus plafon (*breakout* >10).

| # | Kriteria | Bobot | Inti |
|---|---|---|---|
| 1 | **Anti-Halusinasi / Verifiability** | ×2 | Output bertumpu ground-truth (deterministik/on-chain), bukan tebakan LLM → jawaban atas "not another chatbot" |
| 2 | Deliverable Atomik | ×1.5 | 1 call = nilai utuh |
| 3 | Pay-per-Call Repeatable | ×1.5 | Harga receh, dipanggil berulang → volume |
| 4 | Agent-Native / Composable | ×1.5 | Dikonsumsi agent lain, blok lego |
| 5 | Moat Data/Metode | ×1 | Data/algoritma sulit ditiru |
| 6 | Hook Emosional / Kebaruan | ×1 | Sudut yang bikin "harus coba" |
| 7 | Outcome Terukur | ×1 | Angka/keputusan konkret |
| 8 | Timing / Real-time | ×1 | Nilai naik karena lebih cepat/baru |

### 2.2 Benchmark ASP live okx.ai (rubrik sama, nominal max 105)

Standar pasar berada di **~52–88**. Yang menembus 80+ semuanya kuat di Anti-Halusinasi + Agent-Native + Real-time.

| ASP (live) | Total | Kekuatan | Kelemahan |
|---|---|---|---|
| CoinAnk OpenAPI | **88** | data faktual, agent-native, 80 API | hook rendah |
| Onchain Data Explorer | **84** | 180 chain, tim OKX | hook rendah |
| Barker Yield | **83.5** | 0.001/call super-repeatable | moat sedang |
| AgentFund | **81.5** | eksplisit for-agents, terukur | hook rendah |
| BrandCanvas | 73 | on-chain provenance, atomik | timing lemah |
| PixelBrief (10K sold) | 63 | atomik sempurna | verifiability & moat lemah — menang via volume/harga |

### 2.3 Problem — VALID KUAT & sedang memuncak (2026)

| Bukti | Angka | Sumber |
|---|---|---|
| Konten internet baru = AI-generated | **50–64%** (2026) | MIT CSAIL + Oxford / Graphite-Originality.ai |
| Ditambahkan 2025 | 8,3M artikel, 1,2T post sosial, 47M listing produk AI | idem |
| "AI slop" | **Word of the Year 2025** (Merriam-Webster); sebutan naik 9× | Digital Watch Observatory |
| "Trust penalty" | kesadaran asal-AI menurunkan kepercayaan; autentisitas = mekanisme utama trust | American Impact Review, Mar 2026 |
| NFT | 80% free-mint OpenSea plagiat; 3.000+ seniman sebut lelang AI Christie's "mass theft" | CSRIPR/NUSRL; CNN |
| IP ownership AI | "dari teoretis → **urgensi operasional**" (2026) | Norton Rose Fulbright |

**Verdict problem:** autentisitas jadi **langka saat konten AI membanjir** → kelangkaan bernilai. Bukti willingness-to-pay nyata: **Adobe menanggung biaya hukum + ganti rugi** untuk output Firefly yang digugat (enterprise membayar; Midjourney/Stable Diffusion tak menawarkan); pasar asuransi IP bernilai miliaran; hukum trademark *first-to-use* menilai **"bukti KAPAN pertama dipakai lebih berharga daripada registrasinya."**

### 2.4 Skor objektif Cachet vs alternatif (post-validasi)

Enam arah konsep diadu; Cachet (mint vertikal + First-Seen Guarantee) menang setelah demand & threat diperhitungkan.

| Konsep | Skor | Catatan |
|---|---|---|
| **Cachet (mint + First-Seen Guarantee)** | **≈112.5** | demand terbukti, whitespace, problem tervalidasi |
| Provenance Anchor | ~109 | disclosure dikomoditisasi C2PA gratis |
| Royalty Rail | ~109.5 | royalti tak ada demand di okx.ai |
| Pricing Oracle | ~105–110 | pricing mendahului pasar |
| Rug/Dilution Oracle | ~106 | pasar padat (CoinAnk + tool OKX) — berbahaya |
| Trust-agent verification | ~104.5 | niche sudah diisi Attestra/EVIDIQ, nyaris tak pakai keahlian inti |

**Skor Cachet ≈112.5:** Anti-Halusinasi 12×2 · Agent-Native 11×1.5 · Pay-per-Call 10×1.5 · Atomik 10×1.5 · **Hook 11🚀** (AI slop = Word of Year) · **Timing 11🚀** (krisis autentisitas + EU AI Act) · **Outcome 11🚀** (jaminan berasuransi) · Moat 9 (provenance ramai → moat = deteksi+asuransi). Di atas standar pasar (52–88) & semua alternatif.

---

## 3. PEMBEDA UTAMA & POSITIONING

### 3.1 Positioning (memimpin DETEKSI + JAMINAN, bukan provenance)

Kategori yang diklaim = **"originality assurance / verified-original minting"** — BUKAN "content provenance" (sudah dikuasai Numbers Protocol).

> Untuk **agent & kreator yang mint konten** yang butuh karyanya **terbukti-pertama & tepercaya** di tengah banjir AI — **Cachet** adalah **lapis mint verified-original** yang **mendeteksi salinan terhadap registry on-chain dan menerbitkan sertifikat "first-seen" berasuransi.** Tidak seperti alat provenance (Numbers, C2PA) yang hanya mencatat *asal* file, Cachet **membuktikan tak ada yang mendahuluinya — dan menaruh uang di belakang klaim itu.**

### 3.2 Kontras satu kalimat (senjata anti-Numbers)

> *"Provenance memberitahumu dari mana file berasal. Ia tak bisa memberitahu apakah itu salinan — dan tak menaruh uang di jawabannya. Cachet keduanya."*

### 3.3 Reframe nilai: "indemnifikasi IP ala Adobe, terdesentralisasi"

Nilai Cachet bukan "NFT-mu laku +54%" (premium kolektibel, ragu transfer ke konten agent), melainkan **proteksi liabilitas + prioritas IP** — yang **terbukti dibayar bisnis**. Cachet = **"indemnifikasi IP ala Adobe Firefly, tapi terdesentralisasi, generator-agnostik, saat-mint, diasuransikan reserve."** Posisi tajam, terdiferensiasi, didukung WTP nyata.

### 3.4 Identitas & tagline

- **Hero / yang dijual:** *terbukti-pertama + berasuransi* ("proof it's first, money if it's not").
- **Mekanisme (bukan headline):** deteksi duplikat (perceptual-hash) + skor distinctiveness + registry on-chain + reserve asuransi.
- **Aturan penamaan:** JANGAN memimpin dengan "provenance/verification" (ramai). Pimpin dengan **deteksi + jaminan**.
- **Tagline utama:** **"Proof it's first. Money if it's not."**
  Alternatif: *"Verified original — or your money back." · "Prove nothing came before it."*

---

## 4. IDE PRODUK

### 4.1 Value proposition

Pembeli sertifikat Cachet tidak membeli "stiker cantik" — ia membeli **dua hal fungsional**:

1. **Bukti first-use ber-timestamp** — bukti tamper-proof bahwa ia yang pertama, berguna untuk pertahanan trademark/brand priority dan klaim kepemilikan.
2. **Asuransi anti-pelanggaran** — kalau kelak muncul salinan yang lebih tua, ia dikompensasi (seperti indemnifikasi Adobe, tapi untuk konten apa pun).

### 4.2 Model dua-tier (jujur memisahkan yang diasuransikan vs advisory)

| Tier | Sinyal | Sifat | Status |
|---|---|---|---|
| **1. First-seen** | perceptual-hash → salinan persis/near-duplikat | Deterministik (bisa di-re-run siapa pun) | **DIASURANSIKAN** (klaim keras) |
| **2. Distinctiveness** | embedding → novel vs derivatif; + baca mark C2PA/SynthID (deklarasi-AI, reliabel bila ada) | Probabilistik | **ADVISORY** (skor, dilabeli jujur, tak pernah diasuransikan) |

Pemisahan ini fondasi kepercayaan: **klaim keras hanya di tier deterministik**; sinyal probabilistik jujur diberi label "advisory".

### 4.3 Output: Content Authenticity Profile

Bukan cap biner "AI/bukan" (tak reliabel — OpenAI sendiri menutup detektornya). Melainkan profil multi-sinyal:

- **Pertama?** — verdict first-seen + jarak ke tetangga terdekat.
- **Distinctive atau generik?** — skor novelty (menangkap slop yang derivatif, tanpa mengklaim "ini AI").
- **Deklarasi-AI ada?** — baca C2PA/SynthID bila hadir (reliabel hanya saat mark ada).

### 4.4 The First-Seen Guarantee (level-ide)

Reframe kunci dari preseden: **jangan mengasuransikan "keaslian"** (opini, magnet adverse-selection — bahkan ARIS, satu-satunya penjamin title seni, TAK mengasuransikan authenticity). **Asuransikan PRIORITAS/first-seen** — klaim deterministik yang bisa dibuktikan: *"per timestamp T, tak ada near-duplicate di registry — kamu registrant pertama."*

- **Underwriting:** scan perceptual-hash + embedding → skor risiko → menetapkan premi, atau **menolak** aset berisiko tinggi.
- **Exclusion (anti adverse-selection):** kreator beratestasi; menyembunyikan prior-art / fraud → coverage **batal** (prinsip ARIS *"tell us what you know"*).
- **Klaim/dispute:** siapa pun boleh menantang dengan bukti (aset lebih tua + timestamp); penantang benar dapat **bounty** dari bond ter-slash → **ekosistem pemburu-salinan berbayar**.

**Batas jujur:** Cachet memberi **bukti + asuransi**, bukan kepastian hukum. "First-seen" ≠ "dijamin 100% orisinal". Tier fuzzy (remix gaya berat) **tidak diasuransikan** — hanya tier near-duplicate deterministik.

### 4.5 Bootstrap bertahap (mengatasi cold-start tanpa modal besar)

Cachet tak perlu jadi "asuransi kaya" — cukup jadi **juri risiko**; modalnya dari pihak lain (model pasar, à la Lloyd's). Diterapkan bertahap, pemicu antar-fase = volume premi (otomatis):

- **Fase 1 (volume nol):** **deposit kreator** menjamin klaimnya sendiri (modal Cachet = nol, sekaligus menyaring penjiplak) + plafon coverage = isi kas. Jalan sejak menit pertama tanpa investor.
- **Fase 2 (volume tumbuh):** premi mengendap → kas menebal → plafon naik otomatis.
- **Fase 3 (premi ramai):** buka **kolam staking** (model Nexus Mutual — staker dapat premi, di-burn saat klaim; $18,5M dibayar sejak 2019). Investor datang otomatis karena ada premi nyata dikejar.

Registry cold-start diatasi dengan **pre-seed korpus publik** (koleksi NFT/karya publik) → "tak ada near-duplicate" bermakna sejak hari-1; disimpan sebagai hash/embedding (turunan non-reversibel), bukan konten.

---

## 5. FITUR-FITUR (level-ide)

| # | Fitur | Deskripsi |
|---|---|---|
| F1 | **Duplicate/Originality Engine** | perceptual-hash (near-duplicate deterministik) + embedding (distinctiveness). Otak deteksi. |
| F2 | **First-Seen Certificate** | sertifikat ber-timestamp on-chain, dilekatkan ke aset saat mint; bukti prioritas. |
| F3 | **Insured Guarantee** | payout kalau salinan lebih tua terbukti muncul; self-enforcing lewat reserve + oracle. |
| F4 | **Content Authenticity Profile** | output multi-sinyal (pertama? · distinctive? · deklarasi-AI?), plain-language. |
| F5 | **x402 Pay-per-Call** | verify murah (~0.01–0.05); certify+mint lebih mahal (termasuk premi). |
| F6 | **Challenge & Bounty** | siapa pun menantang dgn bukti; penantang benar dapat potongan bond → pemburu-salinan berbayar. |
| F7 | **Risk-Priced Premium** | premi asuransi ditetapkan dari skor risiko; aset berisiko tinggi ditolak (gate). |
| F8 | **Creator Deposit (Fase 1)** | jaminan collateralized per-aset; nol modal protokol; menyaring penjiplak. |
| F9 | **On-Chain Attestation** | hash bukti + verdict tercatat on-chain, dapat di-embed ke metadata. |
| F10 | **Registry Network-Effect** | tiap mint menyemai registry → deteksi makin akurat seiring waktu. |
| F11 | **Living Re-Scan (roadmap)** | registry re-scan otomatis → picu klaim saat salinan baru muncul. |
| F12 | **C2PA/SynthID Reader** | membaca deklarasi-AI bila ada (reliabel saat mark hadir) sebagai sinyal advisory. |

---

## 6. TABEL "WHY DIFFERENT"

| | **Cachet** | Numbers Protocol | Story Protocol | BrandCanvas | Verisart |
|---|---|---|---|---|---|
| Deteksi duplikat/originalitas | ✅ | ❌ | ❌ | ❌ | sebagian |
| Sertifikat first-seen berasuransi | ✅ | ❌ | ❌ | ❌ | ❌ |
| Native okx.ai (agent-mint, x402) | ✅ | ❌ | ❌ | ✅ | ❌ |
| Provenance on-chain | ✅ | ✅ | ✅ | ✅ | ✅ |
| Menjamin PRIORITAS (bukan keaslian) | ✅ | ❌ | ❌ | ❌ | — |

**Kontras implisit:** provenance = *tabel taruhan masuk*, bukan diferensiator. Diferensiator Cachet = **deteksi + jaminan berasuransi + native okx.ai**.

---

## 7. RISIKO & MITIGASI

| Risiko | Prob | Dampak | Mitigasi | Status |
|---|---|---|---|---|
| **T1 Problem-solution mismatch** (dedup ≠ lawan AI-slop novel) | High | High | Persempit klaim ke plagiarisme/copymint + tambah tier-2 distinctiveness (jujur, bukan AI-detection) | ✅ Fixed |
| **T2 Registry cold-start** (registry kosong tak menangkap apa pun) | High | High | Pre-seed korpus publik + tiap mint menyemai + tier-2 bermakna pra-skala | ✅ Fixed |
| **T3 Premium tak transfer ke konten agent** | High | High | Reframe nilai ke proteksi-liabilitas + prioritas-IP (WTP terbukti: Adobe/asuransi-IP/first-use) | ✅ Berbalik jadi kekuatan |
| **T4 Badge diabaikan marketplace** | High | Med | Nilai inti = payout self-enforcing (tak butuh marketplace); lekatkan saat-mint | 🟡 Dimitigasi (GTM residual) |
| **T5 Platform risk (OKX bisa bangun) + tech tak defensible** | Med | Med | Moat riil = registry network-effect + reserve, bukan algoritma pHash | 🟡 Sedang |
| **T6 Kompleksitas terbaca over-engineered** | Med | Med | Demo fokus 1 alur (verify→mint→certificate); sisanya roadmap | 🟡 Sedang |
| **T7 Regulasi asuransi + solvabilitas + adverse-selection** | Med | Med | Struktur discretionary-mutual; DRS-gate + cap + exclusion fraud; bootstrap bertahap | 🟢 Tercakup |

---

## 8. FAQ-JURI (siap dijawab di demo / Q&A — untuk menetralkan skeptisisme)

1. **"Ini cuma AI-detector lagi?"** → BUKAN. Kami tak mendeteksi AI (OpenAI sendiri tutup detektornya: 26% TP/9% FP). Kami **membuktikan PRIORITAS** via perceptual-hash deterministik + timestamp on-chain. Yang dijamin = "first-seen", bukan "apakah ini AI".
2. **"Kenapa percaya badge Cachet? Kalian belum dikenal."** → Tak perlu percaya kami. Trust = **matematika** (hash bisa di-re-run + bukti on-chain) + **uang** (diasuransikan, bisa ditantang siapa pun).
3. **"Uang asuransinya dari mana? Kalian tak punya modal."** → Kami tak pernah pakai modal sendiri. Fase-1 = deposit kreator; Fase-3 = kolam yield-hunter (model Nexus Mutual, $18,5M dibayar sejak 2019). Kami menilai risiko & ambil potongan.
4. **"Sebenarnya kalian menjamin apa?"** → **PRIORITAS/first-seen**, bukan keaslian estetik / "bukan-AI". Sempit, terbukti, jujur — seperti ARIS mengasuransikan *title* bukan *authenticity*.
5. **"Apa yang cegah orang mengasuransikan salinan yang ia tahu jiplakan?"** → Gate tolak risiko tinggi; fraud/menyembunyikan prior-art → coverage batal; deposit kreator di-slash duluan.
6. **"pHash bisa dikelabui edit berat/style-transfer."** → Benar. Kami hanya **MENJAMIN tier near-duplicate** (deterministik). Tier fuzzy = advisory, tak diasuransikan.
7. **"Siapa yang cari & buktikan salinan?"** → Optimistic oracle + **bounty**: siapa pun buktikan salinan lebih tua dapat potongan bond → pemburu-salinan berbayar.
8. **"Ada demand-nya? Tak ada agent okx.ai pakai royalti."** → Kami tak jual royalti. Kami jual **verified-original saat MINT** — demand mint/branding terbukti (PixelBrief 10K sold; task brand-kit di mana-mana). Autentisitas bernilai (Adobe indemnification, asuransi IP).
9. **"Story Protocol sudah IP on-chain."** → Story = lisensi dideklarasikan+tetap, butuh registrasi turunan. Kami deteksi turunan **tak-terdeklarasi** + native okx.ai (Story tidak). Komplementer.
10. **"Numbers Protocol bisa masuk okx.ai & kalahkan kalian."** → Numbers = provenance saat-pembuatan; tak punya deteksi-duplikat, First-Seen guarantee, atau skor risiko. Kalau masuk, kami komplementer (pakai standar mereka + tambah dedup+asuransi). Moat = registry yang tumbuh + reserve.
11. **"Ini asuransi ilegal?"** → Distrukturkan sebagai **discretionary mutual / crypto-cover**, bukan asuransi teregulasi; perlu kajian yurisdiksi.
12. **"Pasar okx.ai masih recehan ($2.124) — mana uangnya?"** → Hackathon dinilai atas kualitas ASP, bukan revenue. Problem kami di pasar luas (50–64% konten AI); okx.ai = kanal distribusi awal. Fase-1 jalan tanpa volume.
13. **"Bukankah label 'verified' menyesatkan?"** → Justru kami sengaja tak klaim "100% orisinal". Kami klaim persis yang terbukti: "first-seen per T" + similarity/skor transparan. Kejujuran scope = fitur kepercayaan.

---

## 9. DECISION LOG

| Tanggal | Keputusan | Alasan |
|---|---|---|
| 2026-07-20 | Pelanggan utama = **agent lain (middleware)** → berkembang jadi **agent MINT vertikal** | Bergantung demand terbukti (mint/branding), bukan adopsi agent lain |
| 2026-07-20 | Fokus modalitas = **gambar dulu**, arsitektur siap extend teks | Kompetitor Art Creation = pemanggil alami; demo paling meyakinkan |
| 2026-07-20 | Konsep final = **Cachet (mint + First-Seen Guarantee)** | Demand terbukti + whitespace + reuse keahlian inti |
| 2026-07-20 | Jamin **PRIORITAS/first-seen**, bukan keaslian | Keaslian = magnet adverse-selection (ARIS pun tak asuransikan) |
| 2026-07-21 | Positioning **memimpin deteksi+jaminan**, bukan provenance | Provenance ramai (Numbers/C2PA) → kalah kalau frontal |
| 2026-07-21 | Tangani AI-slop lewat **distinctiveness (advisory)**, bukan AI-detection | AI-detection tak reliabel; distinctiveness jujur & terukur |
| 2026-07-21 | Reframe nilai ke **proteksi-liabilitas + prioritas-IP** | WTP terbukti (Adobe indemnification, asuransi IP, first-use law) |
| 2026-07-21 | Bootstrap modal **bertahap** (deposit kreator → kolam staking) | Cachet tak pernah butuh modal sendiri; hindari telur-ayam |

---

## 10. GLOSSARY & RESOURCE LINKS

**Glossary:** *First-Seen* = klaim "tak ada near-duplicate lebih tua di registry per timestamp T"; *Perceptual-hash* = sidik jari gambar tahan kompresi/resize (deteksi salinan deterministik); *Distinctiveness score* = ukuran novel vs derivatif via embedding (advisory); *Content Authenticity Profile* = laporan multi-sinyal (pertama/distinctive/deklarasi-AI); *Optimistic oracle* = verdict dianggap benar kecuali ditantang dalam jendela waktu; *Discretionary mutual* = skema saling-jamin non-asuransi-teregulasi; *ASP* = Agent Service Provider di okx.ai; *x402* = standar bayar HTTP-402 stablecoin pay-per-call.

**Sumber problem & preseden:**
- Statistik konten AI: MIT CSAIL + Oxford Internet Institute; Graphite/Originality.ai; Digital Watch Observatory.
- Ketidakandalan AI-detector: OpenAI (penutupan classifier); RAID benchmark.
- Premi autentisitas: "In Art We Trust" (Management Science).
- Indemnifikasi IP: Adobe Firefly (Fast Company; Adobe Business).
- Title insurance & exclusion: ARIS Title Insurance (Argo Group).
- Model asuransi terdesentralisasi: Nexus Mutual; UMA optimistic oracle.
- Provenance standar: C2PA (`spec.c2pa.org`); Numbers Protocol (ERC-7053).
- First-to-use trademark: World IP Review.

**Platform:** OKX.AI (`okx.ai`) · x402 (`x402.org`) · OKX Onchain OS.
