# CACHET — Ideation Brief v2.1 (FINAL)

Originality-Assurance Mint Layer for the Agent Economy — OKX.AI Genesis Hackathon (ASP / Agentic Commerce)

2026-07-21

**Versi: 2.1-Ideation FINAL | Status: Ide selesai di level ideation — putaran kritik berikutnya = diminishing returns; energi pindah ke Technical Implementation Doc**
**Primary Track:** Best Product + Software Utility (paralel: Revenue Rocket via verify murah-volume, Artistic Excellence, Social Buzz)

> **Ruang lingkup:** dokumen IDE — problem, positioning, value prop, fitur (level-ide), risiko, FAQ, decision log. TIDAK memuat arsitektur/timeline (→ *Technical Implementation Doc*) maupun panduan demo/README (→ *Delivery Implementation Doc*).
>
> **Perubahan besar dari v1:** sepuluh temuan stress-test (Bagian 1.1–1.2) diintegrasikan penuh. Yang paling struktural: coverage kini **melekat ke aset & transferable ke pembeli** (reframe title-insurance), sertifikat kini **seasoned** (kepercayaan tumbuh seiring bertahan dari challenge), dan **Living Re-Scan naik dari roadmap menjadi pilar model bisnis**. Output berganti nama dari "Content Authenticity Profile" → **"Originality Profile"**.
>
> **Perubahan v2.0 → v2.1 (putaran final, Bagian 1.3):** menutup dua lubang mekanisme terakhir — **front-running registry** (solusi: commit-reveal + integrasi saat-generasi) dan **loop fraud self-dealing** (solusi: waiting period + plafon terikat reputasi + analisis graph wallet); membereskan **kontradiksi Fase-1** (fraud bond dipisah dari coverage; sertifikat perpetual, coverage berjangka); dan menetapkan **Golden Path** sebagai aturan penceritaan tunggal.

---

## 1. CELAH KONSEPTUAL v1 & PENGEMBANGAN YANG BELUM TERGALI

Bagian ini adalah hasil stress-test terhadap v1. Setiap poin: apa celahnya, kenapa fatal bila dibiarkan, dan bagaimana v2 menyelesaikannya. Semua poin **DITERIMA** dan sudah terintegrasi ke bagian-bagian selanjutnya.

### 1.1 Celah konseptual (yang bisa mematahkan ide bila ditekan)

**G1 — Gap semantik: "first-seen di registry" ≠ "first di dunia".**
Nilai yang dijual (prioritas trademark, pertahanan IP) butuh "pertama di mana pun"; yang bisa dibuktikan hanya "pertama di registry per timestamp T". Pre-seed memperkecil gap tapi tidak menutupnya.
→ **Solusi v2: Seasoned Certificate.** Sertifikat bukan klaim biner — kepercayaannya *tumbuh seiring waktu bertahan dari challenge terbuka*. Sertifikat berumur 6 bulan yang selamat dari tantangan publik jauh lebih bermakna daripada yang baru terbit. Premi turun / plafon coverage naik seiring umur sertifikat. Kelemahan berubah jadi fitur; moat registry mendapat dimensi waktu, bukan cuma volume. (→ §5.5, F13)

**G2 — Sisi permintaan terbalik: v1 menjual ke pihak yang paling tidak butuh.**
Kreator jujur tahu dirinya orisinal → WTP rendah. Yang paling termotivasi membeli justru penjiplak yang ingin selubung legitimasi (adverse selection). Preseden yang dikutip v1 sendiri menunjuk jawabannya: **title insurance dibeli saat transaksi dan melindungi PEMBELI, bukan penjual.**
→ **Solusi v2: Transferable Buyer Coverage.** Coverage melekat pada aset dan berpindah ke pemegang berikutnya. Pembeli NFT/konten terlindungi bila kelak terbukti jiplakan. WTP pembeli jauh lebih jelas, marketplace punya alasan mensyaratkannya, dan sertifikat menaikkan nilai jual-kembali aset. Ini **menyelesaikan** (bukan memitigasi) T3 dan T4 dari v1 sekaligus. Pengembangan berdaya-ungkit terbesar di v2. (→ §5.4, F14)

**G3 — Klaim "deterministik" tercemar di titik paling kritis: adjudikasi challenge.**
Verify memang deterministik, tapi saat penantang membawa bukti "salinan lebih tua" dari off-chain — EXIF bisa dipalsukan, tanggal bisa dikarang. Justru di momen payout, sistem berhenti deterministik; optimistic oracle bisa tenggelam di sengketa tak terputuskan.
→ **Solusi v2: Kelas Bukti Admissible.** Challenge hanya sah dengan timestamp yang dapat diverifikasi: (a) on-chain, (b) snapshot web-archive, (c) capture ber-C2PA-signature. Bukti di luar kelas ini ditolak otomatis. (→ §5.6)

**G4 — Challenge tanpa stake penantang = pintu griefing.**
v1 memberi bounty untuk penantang benar tapi tidak menyebut risiko penantang salah → sertifikat populer bisa dibanjiri challenge spam gratis.
→ **Solusi v2: Challenger Stake simetris.** Menantang butuh bond; challenge gagal → stake di-slash (sebagian ke pemegang sertifikat yang diganggu, sebagian ke kas). (→ §5.6)

**G5 — pHash bisa dikelabui dua arah; v1 baru menjawab satu.**
FAQ v1 #6 menjawab arah false-negative coverage (remix berat tak dijamin — benar). Yang belum: **adversarial evasion** — penjiplak memodifikasi gambar hingga lolos radius pHash tapi perseptual identik, lalu mendapat sertifikat berasuransi untuk jiplakan (serangan terhadap perceptual hash terdokumentasi, kasus NeuralHash).
→ **Solusi v2: ensemble multi-hash + zona abu-abu embedding** — "terlalu dekat untuk disetujui, terlalu jauh untuk ditolak otomatis" → advisory-only atau ditolak dari coverage. + FAQ baru #14. (→ §5.2, FAQ 14)

**G6 — Parameter coverage tak terdefinisi — dan itu bagian dari ide, bukan detail teknis.**
Berapa kompensasinya? Berapa lama berlakunya? Jaminan perpetual = tail risk tak terbatas.
→ **Solusi v2:** (a) **coverage = declared value** (harga mint/jual yang dideklarasikan; premi menskalakan dengannya — persis title insurance); (b) **coverage berjangka** (1 tahun, dapat diperpanjang) → sekaligus menciptakan **revenue perpanjangan berulang**. (→ §5.4)

**G7 — Nama "Content Authenticity Profile" bertentangan dengan positioning sendiri.**
Seluruh brief menolak mengklaim "authenticity", lalu output utamanya bernama Authenticity Profile.
→ **Solusi v2: rename → "Originality Profile".** Konsistensi bahasa = bagian dari kredibilitas klaim. (→ §5.3)

### 1.2 Pengembangan yang belum tergali di v1

**D1 — Distribusi belum punya mesin: kenapa PixStudio mau memanggil Cachet?**
v1 mengasumsikan agent generator akan memanggil tanpa memberi mereka alasan.
→ **Revenue-share untuk agent pemanggil**: agent mint yang merutekan trafik ke Cachet dapat potongan premi. Setiap art-generator di okx.ai menjadi tenaga penjual, dan output mereka naik nilai karena bersertifikat. Cachet berubah dari "layanan yang berharap dipanggil" → "infrastruktur yang menguntungkan pemanggilnya". (→ F15)

**D2 — Living Re-Scan naik kelas: dari baris roadmap → pilar model bisnis.**
Sertifikat one-time = transaksi sekali. **Monitoring berlangganan** ("kami terus mengawasi registry & sumber publik untuk salinan karyamu; klaim terpicu otomatis") = revenue berulang + justru mekanisme yang membuat guarantee hidup — tanpa re-scan, klaim hanya terjadi bila korban kebetulan menemukan salinannya sendiri. (→ F11 dipromosikan)

**D3 — Lapisan reputasi kreator via ERC-8004.**
OKX.AI punya sistem identitas agent ERC-8004. Kreator/agent dengan rekam jejak sertifikat bersih → premi makin murah, limit makin tinggi. Switching cost personal (rekam jejak hidup di Cachet), moat melampaui registry, dan Cachet tertanam ke rel identitas platform. (→ F16)

**Prioritas daya ungkit:** G2 (buyer coverage) > G1 (seasoned certificate) ≈ D1 (rev-share) > sisanya (pengetatan mekanisme — wajib dijawab, tak mengubah bentuk produk).

### 1.3 Putaran final (v2.1) — dua lubang mekanisme, satu kontradiksi, satu risiko presentasi

Stress-test terakhir atas v2.0. Semua **DITERIMA** dan terintegrasi. Setelah ini ide dinyatakan **final di level ideation**.

**P1 — Front-running registry ("registry sniping") — lubang terbesar yang tersisa.**
First-seen menghadiahi *registrant tercepat*, bukan *kreator sejati*. Serangan: seniman memposting preview karya di media sosial sebelum mint → scraper mendaftarkannya ke Cachet lebih dulu → Cachet menerbitkan sertifikat **untuk pencurinya** — sistem melegitimasi pencurian yang seharusnya ia lawan. Kegagalan mode terburuk: bukan gagal mendeteksi, tapi mempersenjatai penjiplak.
→ **Solusi v2.1 (tiga lapis):** (a) **Commit-Reveal** — kreator mengunci *hash komitmen* (murah, privat) sebelum karya terlihat publik; saat mint, reveal membuktikan kepemilikan sejak timestamp komitmen. Sekaligus menjawab "apakah panggilan verify membocorkan karyaku ke registry sebelum mint?" — tidak: komitmen tidak mengungkap konten. (b) **Integrasi saat-generasi** — agent generator memanggil Cachet *di dalam pipeline* sehingga karya ter-register sebelum pernah terlihat publik; ini memberi D1/rev-share argumen keamanan struktural, bukan cuma insentif uang. (c) Karya ber-**C2PA capture-signature** otomatis mengalahkan registrant belaka dalam sengketa (sudah masuk kelas bukti admissible). (→ §5.8, F17, T11, FAQ 16)

**P2 — Loop fraud klasik asuransi: self-dealing claim.**
Serangan: penipu diam-diam menaruh "salinan lebih tua" dengan timestamp on-chain admissible → mint versi baru via Cachet dengan declared value tinggi → jual ke kaki-tangan → kaki-tangan "menemukan" salinan lama dan mengklaim payout dari kolam Fase 3. Semua bukti sah; fraud-exclusion sulit dipakai karena "pengetahuan prior-art" tak terbuktikan. Nol nilai di Fase 1 (payout dari deposit penipu sendiri), tapi vektor drain nomor satu begitu kolam Fase 3 buka.
→ **Solusi v2.1 (tiga lapis, konsisten dengan mekanisme yang ada):** (a) **Waiting period** — coverage aktif N hari setelah terbit; klaim atas prior-art yang "baru ditemukan" sehari setelah mint = ditolak; (b) **plafon coverage terikat reputasi ERC-8004 + seasoning** — F13/F16 kini berfungsi keamanan, bukan cuma diskon premi: kreator baru tanpa rekam jejak tak bisa langsung declared-value besar; (c) **analisis graph wallet** — prior-art yang berasal dari wallet ter-link dengan pembeli/kreator → klaim ditolak. (→ §5.4, T12, FAQ 17)

**P3 — Kontradiksi internal Fase 1: deposit = declared value adalah self-insurance.**
v2.0 mencampur dua fungsi: deposit kreator menjamin klaim *dan* coverage = declared value → kreator karya 1 ETH harus mengunci ~1 ETH; pembeli terlindungi tapi kreator tak dapat apa-apa sambil modalnya terkunci. Tak ada yang mau.
→ **Solusi v2.1: pisahkan dua fungsi.** (a) **Fraud bond** — kecil & tetap, menyaring penjiplak, di-slash saat fraud (fungsi asli F8); (b) **coverage** — di Fase 1 diberi **plafon rendah yang jujur** ("coverage terbatas selama bootstrap"), naik saat kolam Fase 2–3 terisi. Sekalian dieksplisitkan pemisahan yang di v2.0 masih tersirat: **sertifikat/bukti = PERPETUAL; coverage = berjangka & diperpanjang.** Bukti prioritas tak ikut kedaluwarsa saat coverage habis. (→ §5.4, §5.7, F3, F8)

**P4 — Risiko presentasi: 16 fitur mulai kehilangan siluet.**
Reviewer memberi ide ini 3–5 menit; yang harus mereka ingat satu kalimat: *"proof it's first, money if it's not."*
→ **Solusi v2.1: Golden Path** — satu alur 4 langkah (**verify → certify → coverage ikut pembeli → challenge**) menjadi SATU-SATUNYA hal yang di-demo dan dijelaskan; semua lainnya (Watch, rev-share, reputasi, seasoning, commit-reveal) = **depth layer satu-kalimat** yang hanya keluar saat ditanya. Bukan memotong ide — memutuskan urutan penceritaannya. Ini jawaban konkret T6. (→ §2.1)

---

## 2. RINGKASAN EKSEKUTIF

**Cachet adalah layanan (ASP) yang dipanggil agent & kreator saat mencetak konten — untuk membuktikan karyanya "yang pertama" dan menaruh uang di belakang klaim itu; dan perlindungan itu ikut berpindah ke siapa pun yang membeli karyanya.**

Di 2026, **50–64% konten internet baru dihasilkan AI**. Autentisitas jadi langka justru saat konten membanjir — dan yang langka itu bernilai. Tak ada cara bagi konten yang baru di-mint untuk membuktikan **"aku yang pertama, bukan salinan"** — sambil menanggung risiko bila salah.

Cachet bekerja lewat **satu panggilan** (x402/MCP di okx.ai):

1. **Verify** — cek konten terhadap registry on-chain: salinan/duplikat? distinctive vs generik?
2. **Certify & Mint** — terbitkan **sertifikat "First-Seen"** ber-timestamp on-chain, dilekatkan ke aset saat mint — dan sertifikat itu **menua dengan baik**: makin lama bertahan dari challenge, makin kuat kepercayaannya (*seasoned certificate*).
3. **Guarantee** — sertifikat **ber-bond & transferable**: bila kelak terbukti ada salinan lebih tua, **pemegang aset saat itu** (kreator ATAU pembelinya) dikompensasi sebesar declared value.
4. **Challenge** — siapa pun boleh menantang dengan bukti admissible + stake; penantang benar dapat bounty, penantang iseng kehilangan stake.
5. **Watch** — langganan re-scan: registry terus dipindai; salinan baru memicu klaim otomatis.

Output = **"Originality Profile"**: *pertama? · distinctive atau derivatif? · deklarasi-AI ada?* — bukan cap biner "AI atau bukan" (tak reliabel), melainkan laporan multi-sinyal yang jujur.

**Satu kalimat untuk juri:** *"The only mint layer that proves your content is first — and pays whoever holds it if it's not."*

**Jangkauan:** ASP di okx.ai, dipanggil via **x402** (stablecoin, pay-per-call) oleh agent generator/minter (PixStudio, Apex10K, XLayer NFT Mint, BrandCanvas, PixelBrief) maupun kreator langsung — dengan **rev-share untuk agent pemanggil** sebagai mesin distribusi.

### 2.1 Golden Path (P4 — aturan penceritaan tunggal)

Satu-satunya alur yang di-demo dan dijelaskan ke reviewer. Semua fitur lain adalah *depth layer* satu-kalimat yang hanya keluar saat ditanya.

| Langkah | Aksi | Yang terlihat |
|---|---|---|
| 1. **Verify** | agent/kreator kirim gambar via x402 | Originality Profile: "tak ada near-duplicate; distinctiveness 0.87" — atau *menangkap copymint nyata live* |
| 2. **Certify** | mint dengan sertifikat First-Seen | timestamp on-chain + certificate page publik yang bisa dicek siapa pun |
| 3. **Coverage ikut pembeli** | aset dijual → jaminan berpindah otomatis | pembeli terlindungi bila kelak terbukti jiplakan ("title insurance untuk konten") |
| 4. **Challenge** | siapa pun menantang dengan bukti + stake | penantang benar dibayar; sertifikat yang selamat makin kuat |

**Depth layer (hanya bila ditanya):** Watch (monitoring berlangganan) · rev-share pemanggil · reputasi ERC-8004 · seasoned certificate · commit-reveal anti-sniping · zona abu-abu anti-evasion.

---

## 3. KENAPA IDE INI (validasi problem, kriteria, benchmark)

### 3.1 Kriteria penilaian (rubrik 8-dimensi hasil riset ASP sukses okx.ai)

| # | Kriteria | Bobot | Inti |
|---|---|---|---|
| 1 | **Anti-Halusinasi / Verifiability** | ×2 | Output bertumpu ground-truth (deterministik/on-chain), bukan tebakan LLM |
| 2 | Deliverable Atomik | ×1.5 | 1 call = nilai utuh |
| 3 | Pay-per-Call Repeatable | ×1.5 | Harga receh, dipanggil berulang → volume |
| 4 | Agent-Native / Composable | ×1.5 | Dikonsumsi agent lain, blok lego |
| 5 | Moat Data/Metode | ×1 | Data/algoritma sulit ditiru |
| 6 | Hook Emosional / Kebaruan | ×1 | Sudut yang bikin "harus coba" |
| 7 | Outcome Terukur | ×1 | Angka/keputusan konkret |
| 8 | Timing / Real-time | ×1 | Nilai naik karena lebih cepat/baru |

### 3.2 Benchmark ASP live okx.ai (nominal max 105; standar pasar ~52–88)

| ASP (live) | Total | Kekuatan | Kelemahan |
|---|---|---|---|
| CoinAnk OpenAPI | **88** | data faktual, agent-native, 80 API | hook rendah |
| Onchain Data Explorer | **84** | 180 chain, tim OKX | hook rendah |
| Barker Yield | **83.5** | 0.001/call super-repeatable | moat sedang |
| AgentFund | **81.5** | eksplisit for-agents, terukur | hook rendah |
| BrandCanvas | 73 | on-chain provenance, atomik | timing lemah |
| PixelBrief (10K sold) | 63 | atomik sempurna | verifiability & moat lemah — menang via volume/harga |

### 3.3 Problem — VALID KUAT & sedang memuncak (2026)

| Bukti | Angka | Sumber |
|---|---|---|
| Konten internet baru = AI-generated | **50–64%** (2026) | MIT CSAIL + Oxford / Graphite-Originality.ai |
| Ditambahkan 2025 | 8,3M artikel, 1,2T post sosial, 47M listing produk AI | idem |
| "AI slop" | **Word of the Year 2025** (Merriam-Webster); sebutan naik 9× | Digital Watch Observatory |
| "Trust penalty" | kesadaran asal-AI menurunkan kepercayaan; autentisitas = mekanisme utama trust | American Impact Review, Mar 2026 |
| NFT | 80% free-mint OpenSea plagiat; 3.000+ seniman sebut lelang AI Christie's "mass theft" | CSRIPR/NUSRL; CNN |
| IP ownership AI | "dari teoretis → **urgensi operasional**" (2026) | Norton Rose Fulbright |

**Verdict problem:** autentisitas langka saat konten AI membanjir → kelangkaan bernilai. WTP nyata: **Adobe menanggung biaya hukum + ganti rugi** untuk output Firefly (enterprise membayar); pasar asuransi IP miliaran dolar; hukum trademark *first-to-use*: **"bukti KAPAN pertama dipakai lebih berharga daripada registrasinya."** Dan preseden title insurance menunjukkan: **pembeli** membayar perlindungan saat transaksi — persis model coverage transferable v2.

### 3.4 Skor objektif Cachet vs alternatif

| Konsep | Skor | Catatan |
|---|---|---|
| **Cachet v2 (mint + transferable First-Seen Guarantee)** | **≈115** | v1 ≈112.5; naik karena G2/G1/D1 memperbaiki Moat & Outcome |
| Provenance Anchor | ~109 | disclosure dikomoditisasi C2PA gratis |
| Royalty Rail | ~109.5 | royalti tak ada demand di okx.ai |
| Pricing Oracle | ~105–110 | pricing mendahului pasar |
| Rug/Dilution Oracle | ~106 | pasar padat — berbahaya |
| Trust-agent verification | ~104.5 | niche terisi, tak pakai keahlian inti |

---

## 4. PEMBEDA UTAMA & POSITIONING

### 4.1 Positioning (memimpin DETEKSI + JAMINAN, bukan provenance)

Kategori yang diklaim = **"originality assurance / verified-original minting"** — BUKAN "content provenance" (dikuasai Numbers Protocol).

> Untuk **agent & kreator yang mint konten** — dan **pembeli yang menampung karyanya** — yang butuh bukti **terbukti-pertama & tepercaya** di tengah banjir AI, **Cachet** adalah **lapis mint verified-original** yang **mendeteksi salinan terhadap registry on-chain dan menerbitkan sertifikat "first-seen" ber-jaminan yang ikut berpindah bersama asetnya.** Tidak seperti alat provenance (Numbers, C2PA) yang hanya mencatat *asal* file, Cachet **membuktikan tak ada yang mendahuluinya — dan menaruh uang di belakang klaim itu, untuk siapa pun pemegangnya.**

### 4.2 Kontras satu kalimat (senjata anti-Numbers)

> *"Provenance memberitahumu dari mana file berasal. Ia tak bisa memberitahu apakah itu salinan — dan tak menaruh uang di jawabannya. Cachet keduanya."*

### 4.3 Reframe nilai: "title insurance untuk konten digital"

v1 memframe "indemnifikasi IP ala Adobe, terdesentralisasi" — masih benar untuk sisi kreator. v2 menajamkannya dengan analogi yang lebih kuat secara struktural: **title insurance**. Pembeli rumah membayar title insurance saat transaksi untuk terlindung dari cacat kepemilikan; **pembeli konten membayar (atau menerima warisan) coverage Cachet untuk terlindung dari cacat orisinalitas.** Coverage melekat ke aset, bukan ke orang. Ini kategori yang WTP-nya sudah terbukti berabad-abad — belum pernah diterapkan ke konten digital saat-mint.

### 4.4 Identitas & tagline

- **Hero:** *terbukti-pertama + berjaminan + ikut berpindah* ("proof it's first, money if it's not — for whoever holds it").
- **Mekanisme (bukan headline):** dedup ensemble multi-hash + skor distinctiveness + registry on-chain + bond/reserve + challenge market.
- **Aturan penamaan:** JANGAN memimpin dengan "provenance/verification". Pimpin dengan **deteksi + jaminan**. Hindari kata **"insurance"** di listing ASP (risiko flag compliance reviewer) — gunakan *"guarantee / collateralized certificate / challenge bond"*.
- **Tagline utama:** **"Proof it's first. Money if it's not."**
  Alternatif: *"Verified original — or your money back." · "Title insurance for the mint age."*

---

## 5. IDE PRODUK

### 5.1 Value proposition

Pembeli sertifikat Cachet membeli **tiga hal fungsional**:

1. **Bukti first-use ber-timestamp** — tamper-proof, berguna untuk pertahanan trademark/brand priority dan klaim kepemilikan; **makin tua makin kuat** (seasoned).
2. **Jaminan anti-pelanggaran transferable** — bila muncul salinan lebih tua, **pemegang aset saat itu** dikompensasi sebesar declared value (model title insurance).
3. **Pengawasan berkelanjutan (Watch)** — registry terus dipindai; pelanggaran ditemukan sistem, bukan kebetulan.

### 5.2 Model dua-tier + zona abu-abu (jujur memisahkan yang dijamin vs advisory)

| Tier | Sinyal | Sifat | Status |
|---|---|---|---|
| **1. First-seen** | ensemble multi-hash perceptual → salinan persis/near-duplikat | Deterministik (bisa di-re-run siapa pun) | **DIJAMIN** (klaim keras) |
| **Zona abu-abu** | jarak embedding "terlalu dekat untuk lolos, terlalu jauh untuk tolak otomatis" | Ambang eksplisit | **Advisory-only ATAU ditolak dari coverage** (anti-evasion, G5) |
| **2. Distinctiveness** | embedding → novel vs derivatif; + baca C2PA/SynthID | Probabilistik | **ADVISORY** (skor berlabel jujur, tak pernah dijamin) |

Klaim keras hanya di tier deterministik; sinyal probabilistik berlabel "advisory"; dan **evasion tipis ditangkap zona abu-abu** — tiga lapis kejujuran scope.

### 5.3 Output: Originality Profile

*(rename dari "Content Authenticity Profile" — G7: kami tak mengklaim authenticity, jadi nama output tak boleh mengklaimnya.)*

- **Pertama?** — verdict first-seen + jarak ke tetangga terdekat + **umur sertifikat & jumlah challenge yang selamat** (seasoning).
- **Distinctive atau generik?** — skor novelty (menangkap slop derivatif tanpa mengklaim "ini AI").
- **Deklarasi-AI ada?** — baca C2PA/SynthID bila hadir.

### 5.4 The First-Seen Guarantee (level-ide, diperketat)

Prinsip v1 dipertahankan: **jangan menjamin "keaslian"** (opini, magnet adverse-selection — ARIS pun tidak). **Jamin PRIORITAS/first-seen** — klaim deterministik: *"per timestamp T, tak ada near-duplicate di registry — kamu registrant pertama."*

Parameter baru (G6, G2):

- **Sertifikat ≠ coverage (P3):** **sertifikat/bukti prioritas = PERPETUAL** (tak pernah kedaluwarsa); **coverage = berjangka 1 tahun & dapat diperpanjang** (perpanjangan = revenue berulang; tail risk terbatas). Bukti first-seen-mu tetap berlaku selamanya meski coverage habis.
- **Coverage = declared value, dengan plafon terikat reputasi (P2)** — kreator mendeklarasikan nilai (harga mint/jual); kompensasi & premi menskalakan dengannya; deklarasi berlebihan = premi mahal (self-limiting). Plafon maksimum ditentukan **reputasi ERC-8004 + umur seasoning**: kreator baru tanpa rekam jejak tak bisa langsung declared-value besar.
- **Waiting period (P2)** — coverage aktif N hari setelah terbit; klaim atas prior-art yang "baru ditemukan" segera setelah mint ditolak → mematikan klaim self-dealing kilat.
- **Transferable / melekat ke aset** — coverage berpindah bersama aset ke pemegang berikutnya. Pembeli terlindungi; marketplace punya alasan mensyaratkan; nilai jual-kembali naik.
- **Underwriting:** scan ensemble + embedding → skor risiko → premi, atau **tolak** aset berisiko tinggi / zona abu-abu.
- **Exclusion (anti adverse-selection & anti-self-dealing):** kreator beratestasi; menyembunyikan prior-art / fraud → coverage **batal** (prinsip ARIS *"tell us what you know"*); **fraud bond** di-slash duluan; prior-art dari **wallet ter-link dengan pembeli/kreator** (analisis graph) → klaim ditolak.

**Batas jujur:** Cachet memberi **bukti + jaminan**, bukan kepastian hukum. "First-seen" ≠ "dijamin 100% orisinal". Tier fuzzy tidak dijamin — hanya tier near-duplicate deterministik.

### 5.5 Seasoned Certificate (G1 — jawaban struktural atas gap registry-vs-dunia)

Sertifikat bukan klaim biner sekali-terbit. Ia adalah **klaim yang terus diuji secara publik**:

- Setiap sertifikat terbuka untuk challenge sepanjang masa berlakunya.
- **Makin lama bertahan (dan makin banyak challenge yang gagal), makin tinggi confidence score-nya** — ditampilkan di Originality Profile dan certificate page publik.
- Insentif ekonomi mengikuti: **premi perpanjangan turun / plafon coverage naik** seiring umur sertifikat.
- Efek sistemik: gap "registry ≠ dunia" menyempit *per-aset* seiring waktu — karena pasar pemburu-salinan (F6) sudah diberi insentif untuk menemukannya dan gagal.

### 5.6 Challenge market yang sehat (G3 + G4)

- **Kelas bukti admissible** (challenge di luar ini ditolak otomatis): (a) timestamp on-chain; (b) snapshot web-archive; (c) capture ber-C2PA-signature. Tidak ada adjudikasi atas EXIF/klaim tanggal telanjang → adjudikasi tetap dekat-deterministik.
- **Challenger stake:** menantang butuh bond. Benar → bounty dari bond kreator ter-slash. Salah → stake penantang di-slash (sebagian ke pemegang sertifikat, sebagian ke kas). Simetri ini mematikan griefing sekaligus menjaga bounty tetap menarik.
- **Optimistic oracle:** verdict dianggap benar kecuali ditantang dalam jendela waktu, dengan eskalasi hanya untuk bukti admissible.

### 5.7 Bootstrap bertahap (cold-start tanpa modal besar)

Cachet = **juri risiko**, bukan "asuransi kaya"; modal dari pihak lain (model pasar, à la Lloyd's). Pemicu antar-fase = volume premi. **Koreksi P3:** deposit kreator TIDAK lagi merangkap coverage (itu self-insurance yang tak bernilai bagi kreator) — fungsinya dipisah:

- **Fase 1 (volume nol):** kreator hanya menyetor **fraud bond kecil & tetap** (menyaring penjiplak; di-slash saat fraud) — bukan mengunci senilai karyanya. Coverage diberi **plafon rendah yang jujur** ("coverage terbatas selama bootstrap"), dibayar dari kas premi yang mulai mengendap. Modal Cachet tetap nol.
- **Fase 2 (volume tumbuh):** premi + perpanjangan (§5.4) + langganan Watch (F11) mengendap → kas menebal → plafon naik otomatis.
- **Fase 3 (premi ramai):** buka **kolam staking** (model Nexus Mutual — staker dapat premi, di-slash saat klaim; $18,5M dibayar sejak 2019) → plafon penuh hingga declared value (dalam batas reputasi, §5.4).

Registry cold-start: **pre-seed korpus publik** (koleksi NFT/karya publik) → "tak ada near-duplicate" bermakna sejak hari-1; disimpan sebagai hash/embedding non-reversibel, bukan konten. Pre-seed juga di-desain untuk demo: menangkap copymint nyata secara live.

### 5.8 Commit-Reveal & integrasi saat-generasi (P1 — anti registry-sniping)

First-seen tak boleh menghadiahi *registrant tercepat* alih-alih *kreator sejati*. Tiga lapis pertahanan:

1. **Commit-Reveal:** sebelum karya terlihat publik di mana pun, kreator mengunci **hash komitmen** (murah, privat — tidak mengungkap konten). Saat mint, reveal membuktikan *"aku memegang karya ini sejak timestamp komitmen"* — prior-art pribadi yang tak bisa disnipe scraper. Komitmen juga menjawab kekhawatiran privasi: panggilan verify/commit **tidak** membocorkan karya ke registry sebelum mint.
2. **Integrasi saat-generasi:** agent generator memanggil Cachet **di dalam pipeline** — karya ter-register sebelum pernah dilihat publik. Jendela sniping = nol. Ini alasan keamanan struktural (bukan cuma rev-share) kenapa PixStudio dkk. harus memanggil Cachet di titik generate, memperkuat D1.
3. **Hierarki bukti:** dalam sengketa, karya ber-**C2PA capture-signature** atau komitmen lebih tua otomatis mengalahkan registrant belaka (konsisten dengan kelas bukti admissible §5.6).

---

## 6. FITUR-FITUR (level-ide)

| # | Fitur | Deskripsi | Status v2 |
|---|---|---|---|
| F1 | **Duplicate/Originality Engine** | **ensemble multi-hash** perceptual (near-duplicate deterministik) + embedding (distinctiveness) + **zona abu-abu anti-evasion** | diperkuat (G5) |
| F2 | **First-Seen Certificate** | sertifikat ber-timestamp on-chain, dilekatkan saat mint; bukti prioritas | tetap |
| F3 | **Collateralized Guarantee** | payout bila salinan lebih tua terbukti; coverage = declared value (plafon terikat reputasi), berjangka 1 thn + perpanjangan + **waiting period**; sertifikat tetap **perpetual**; self-enforcing via bond/reserve + oracle | diperketat (G6, P2, P3) |
| F4 | **Originality Profile** | output multi-sinyal (pertama? · distinctive? · deklarasi-AI? · seasoning), plain-language | rename (G7) |
| F5 | **x402 Pay-per-Call** | verify super-murah (0.001–0.01, mesin volume); certify+mint lebih mahal (termasuk premi) | tetap |
| F6 | **Challenge & Bounty Market** | challenge dengan **stake penantang** + **kelas bukti admissible**; penantang benar dapat potongan bond | diperketat (G3, G4) |
| F7 | **Risk-Priced Premium** | premi dari skor risiko; aset berisiko tinggi / zona abu-abu ditolak (gate) | tetap |
| F8 | **Creator Fraud Bond (Fase 1)** | bond **kecil & tetap** (bukan senilai karya): menyaring penjiplak, di-slash saat fraud; coverage Fase-1 berplafon rendah dari kas premi — bukan self-insurance | direvisi (P3) |
| F9 | **On-Chain Attestation** | hash bukti + verdict on-chain, embeddable ke metadata | tetap |
| F10 | **Registry Network-Effect** | tiap mint menyemai registry → deteksi makin akurat | tetap |
| F11 | **Cachet Watch (Living Re-Scan)** | **PILAR BISNIS**: langganan monitoring — registry & sumber publik dipindai berkala, salinan baru memicu klaim otomatis; revenue berulang | dipromosikan (D2) |
| F12 | **C2PA/SynthID Reader** | baca deklarasi-AI bila ada (advisory) | tetap |
| F13 | **Seasoned Certificate** | confidence score tumbuh seiring bertahan dari challenge; premi turun/plafon naik seiring umur | **BARU** (G1) |
| F14 | **Transferable Buyer Coverage** | coverage melekat ke aset, berpindah ke pembeli; model title insurance | **BARU** (G2) |
| F15 | **Caller Rev-Share** | agent pemanggil (PixStudio dkk.) dapat potongan premi → mesin distribusi | **BARU** (D1) |
| F16 | **Creator Reputation (ERC-8004)** | rekam jejak sertifikat bersih → premi turun, limit naik; **plafon coverage terikat reputasi = fungsi keamanan anti-self-dealing**; terikat identitas agent okx.ai | diperkuat (D3, P2) |
| F17 | **Commit-Reveal Anti-Sniping** | hash komitmen privat sebelum karya publik → bukti kepemilikan sejak timestamp komitmen; + integrasi saat-generasi menihilkan jendela sniping | **BARU** (P1) |

---

## 7. TABEL "WHY DIFFERENT"

| | **Cachet** | Numbers Protocol | Story Protocol | BrandCanvas | Verisart |
|---|---|---|---|---|---|
| Deteksi duplikat/originalitas | ✅ | ❌ | ❌ | ❌ | sebagian |
| Sertifikat first-seen ber-jaminan | ✅ | ❌ | ❌ | ❌ | ❌ |
| Coverage transferable ke pembeli | ✅ | ❌ | ❌ | ❌ | ❌ |
| Monitoring berkelanjutan (Watch) | ✅ | ❌ | ❌ | ❌ | ❌ |
| Native okx.ai (agent-mint, x402, rev-share) | ✅ | ❌ | ❌ | ✅ | ❌ |
| Provenance on-chain | ✅ | ✅ | ✅ | ✅ | ✅ |
| Menjamin PRIORITAS (bukan keaslian) | ✅ | ❌ | ❌ | ❌ | — |

**Kontras implisit:** provenance = *tabel taruhan masuk*. Diferensiator Cachet = **deteksi + jaminan transferable + monitoring + native okx.ai**.

---

## 8. RISIKO & MITIGASI

| Risiko | Prob | Dampak | Mitigasi | Status |
|---|---|---|---|---|
| **T1 Problem-solution mismatch** (dedup ≠ lawan AI-slop novel) | High | High | Persempit klaim ke plagiarisme/copymint + tier-2 distinctiveness (jujur, bukan AI-detection) | ✅ Fixed (v1) |
| **T2 Registry cold-start** | High | High | Pre-seed korpus publik + tiap mint menyemai + tier-2 bermakna pra-skala + **seasoning menyempitkan gap per-aset** | ✅ Fixed (v1+G1) |
| **T3 Premium tak transfer ke konten agent** | High | High | **Buyer coverage transferable (G2)**: WTP pembeli menggantikan WTP kreator; + proteksi-liabilitas ala Adobe | ✅ **Diselesaikan** (v2) |
| **T4 Badge diabaikan marketplace** | High | Med | Payout self-enforcing + **coverage transferable memberi marketplace alasan mensyaratkan** + rev-share memberi agent alasan memanggil | ✅ **Diselesaikan** (v2) |
| **T5 Platform risk (OKX bisa bangun) + tech tak defensible** | Med | Med | Moat = registry network-effect + reserve + **rekam jejak seasoning & reputasi (tak bisa di-fork)** | 🟡→🟢 Membaik |
| **T6 Kompleksitas terbaca over-engineered** | Med | Med | **Golden Path (§2.1, P4)**: hanya 4 langkah yang di-demo/dijelaskan; semua fitur lain = depth layer satu-kalimat saat ditanya | ✅ **Diselesaikan** (v2.1) |
| **T7 Regulasi + solvabilitas + adverse-selection** | Med | Med | Discretionary-mutual; gate + cap + exclusion fraud; bootstrap bertahap; coverage berjangka membatasi tail risk | 🟢 Tercakup |
| **T8 Adversarial evasion pHash** (BARU, G5) | Med | High | Ensemble multi-hash + zona abu-abu (advisory/tolak) + seasoning (evasion yang lolos tetap terbuka untuk challenge berbounty) | 🟢 Tercakup |
| **T9 Griefing/spam challenge** (BARU, G4) | Med | Med | Challenger stake di-slash bila salah | 🟢 Tercakup |
| **T10 Sengketa bukti tak terputuskan** (BARU, G3) | Med | High | Kelas bukti admissible eksplisit; di luar itu ditolak otomatis | 🟢 Tercakup |
| **T11 Registry sniping / front-running** (BARU v2.1, P1) | High | **Kritis** (sistem melegitimasi pencuri) | Commit-reveal + integrasi saat-generasi (jendela sniping = 0) + hierarki bukti C2PA/komitmen > registrant belaka | 🟢 Tercakup |
| **T12 Self-dealing claim** (tanam prior-art → klaim via kaki-tangan) (BARU v2.1, P2) | Med | High (drain kolam Fase 3) | Waiting period + plafon terikat reputasi/seasoning + analisis graph wallet + fraud-exclusion; Fase 1 imun (payout dari bond sendiri) | 🟢 Tercakup |

---

## 9. FAQ-JURI (siap dijawab di demo / Q&A)

1. **"Ini cuma AI-detector lagi?"** → BUKAN. Kami tak mendeteksi AI (OpenAI sendiri tutup detektornya: 26% TP/9% FP). Kami **membuktikan PRIORITAS** via perceptual-hash deterministik + timestamp on-chain. Yang dijamin = "first-seen", bukan "apakah ini AI".
2. **"Kenapa percaya badge Cachet? Kalian belum dikenal."** → Tak perlu percaya kami. Trust = **matematika** (hash bisa di-re-run + bukti on-chain, cek sendiri di certificate page publik) + **uang** (ber-jaminan, bisa ditantang siapa pun) + **waktu** (confidence tumbuh tiap hari sertifikat selamat dari challenge).
3. **"Uang jaminannya dari mana? Kalian tak punya modal."** → Kami tak pernah pakai modal sendiri. Fase-1 = fraud bond kreator + kas premi dengan plafon coverage rendah yang jujur; Fase-3 = kolam yield-hunter (model Nexus Mutual, $18,5M dibayar sejak 2019). Kami menilai risiko & ambil potongan.
4. **"Sebenarnya kalian menjamin apa?"** → **PRIORITAS/first-seen**, bukan keaslian estetik / "bukan-AI". Sempit, terbukti, jujur — seperti ARIS mengasuransikan *title* bukan *authenticity*. Kompensasi = declared value, berjangka, melekat ke aset.
5. **"Apa yang cegah orang menjaminkan salinan yang ia tahu jiplakan?"** → Gate tolak risiko tinggi & zona abu-abu; fraud/menyembunyikan prior-art → coverage batal; fraud bond kreator di-slash duluan; dan tiap sertifikat terbuka untuk pemburu-salinan berbounty sepanjang masa berlakunya.
6. **"pHash bisa dikelabui edit berat/style-transfer."** → Benar — dua arah, dan kami tangani keduanya. Arah *coverage*: kami hanya MENJAMIN tier near-duplicate deterministik; tier fuzzy = advisory. Arah *evasion*: lihat FAQ 14.
7. **"Siapa yang cari & buktikan salinan?"** → Optimistic oracle + **bounty**: siapa pun buktikan salinan lebih tua (dengan bukti admissible + stake) dapat potongan bond → pemburu-salinan berbayar. Plus **Cachet Watch**: sistem kami sendiri re-scan berkala dan memicu klaim otomatis.
8. **"Ada demand-nya? Tak ada agent okx.ai pakai royalti."** → Kami tak jual royalti. Kami jual **verified-original saat MINT** — demand mint/branding terbukti (PixelBrief 10K sold). Dan pembayar utamanya bukan cuma kreator: **pembeli** aset mewarisi coverage (WTP title-insurance terbukti berabad-abad), **agent pemanggil** dapat rev-share.
9. **"Story Protocol sudah IP on-chain."** → Story = lisensi dideklarasikan+tetap, butuh registrasi turunan. Kami deteksi turunan **tak-terdeklarasi** + native okx.ai. Komplementer.
10. **"Numbers Protocol bisa masuk okx.ai & kalahkan kalian."** → Numbers = provenance saat-pembuatan; tak punya deteksi-duplikat, guarantee transferable, skor risiko, atau challenge market. Kalau masuk, kami komplementer (pakai standar mereka + tambah dedup+jaminan). Moat = registry yang tumbuh + reserve + rekam jejak seasoning yang tak bisa di-fork.
11. **"Ini asuransi ilegal?"** → Distrukturkan sebagai **discretionary mutual / collateralized guarantee**, bukan asuransi teregulasi; coverage berjangka membatasi tail; perlu kajian yurisdiksi. (Di listing ASP kami memakai istilah "guarantee/bond", bukan "insurance".)
12. **"Pasar okx.ai masih recehan — mana uangnya?"** → Hackathon dinilai atas kualitas ASP, bukan revenue. Problem kami di pasar luas (50–64% konten AI); okx.ai = kanal distribusi awal. Fase-1 jalan tanpa volume; Watch + perpanjangan = revenue berulang begitu ada volume.
13. **"Bukankah label 'verified' menyesatkan?"** → Justru kami sengaja tak klaim "100% orisinal". Kami klaim persis yang terbukti: "first-seen per T" + similarity/skor transparan + umur-bertahan. Kejujuran scope = fitur kepercayaan. (Karena itu pula outputnya bernama *Originality Profile*, bukan *Authenticity*.)
14. **"Penjiplak bisa memodifikasi gambar sedikit sampai lolos radius pHash — lalu dapat sertifikat untuk jiplakan?"** (BARU) → Tiga lapis: (1) **ensemble multi-hash** — mengelabui satu hash ≠ mengelabui semuanya; (2) **zona abu-abu embedding** — "terlalu mirip untuk disetujui" → advisory-only atau ditolak dari coverage; (3) kalaupun lolos, sertifikatnya **terbuka untuk challenge berbounty** — pemilik asli atau pemburu mana pun yang membuktikan prior-art admissible mendapat bayaran, dan coverage penjiplak batal karena fraud-exclusion. Evasion jadi mahal, berisiko, dan berumur pendek.
15. **"Kenapa agent lain (PixStudio dkk.) mau memanggil kalian?"** (BARU) → **Rev-share** + **keamanan**: agent pemanggil dapat potongan premi, output mereka naik nilai karena bersertifikat + ter-cover untuk pembelinya, DAN memanggil di dalam pipeline berarti karya ter-register sebelum terlihat publik (jendela sniping = nol). Kami bukan layanan yang berharap dipanggil; kami infrastruktur yang menguntungkan dan mengamankan pemanggilnya.
16. **"Bagaimana kalau pencuri men-scrape karya seniman dari media sosial dan mendaftarkannya duluan? Kalian malah mensertifikasi pencurinya."** (BARU v2.1) → Tiga lapis: (1) **Commit-reveal** — kreator bisa mengunci hash komitmen privat SEBELUM karyanya terlihat publik; komitmen lebih tua mengalahkan registrant mana pun; (2) **integrasi saat-generasi** — agent memanggil kami di dalam pipeline, jadi karya ter-register sebelum pernah dilihat siapa pun; (3) dalam sengketa, **C2PA capture-signature / komitmen selalu mengalahkan registrant belaka**. First-seen menghadiahi kreator sejati, bukan yang tercepat mengetik.
17. **"Penipu bisa menanam 'salinan lebih tua' sendiri, mint via kalian, jual ke kaki-tangan, lalu kaki-tangan klaim payout."** (BARU v2.1) → Di Fase 1 serangan ini nol nilai — payout dari bond penipu sendiri. Untuk kolam Fase 3: **waiting period** (klaim kilat pasca-mint ditolak), **plafon coverage terikat reputasi ERC-8004 + seasoning** (akun baru tak bisa declared-value besar), **analisis graph wallet** (prior-art dari wallet ter-link pembeli/kreator → klaim ditolak), dan fraud-exclusion membatalkan coverage. Biaya serangan > ekspektasi hasil.

---

## 10. DECISION LOG

| Tanggal | Keputusan | Alasan |
|---|---|---|
| 2026-07-20 | Pelanggan utama = agent lain (middleware) → **agent MINT vertikal** | Demand terbukti (mint/branding) |
| 2026-07-20 | Fokus modalitas = **gambar dulu**, arsitektur siap extend teks | Kompetitor Art Creation = pemanggil alami; demo meyakinkan |
| 2026-07-20 | Konsep final = **Cachet (mint + First-Seen Guarantee)** | Demand + whitespace + reuse keahlian |
| 2026-07-20 | Jamin **PRIORITAS/first-seen**, bukan keaslian | Keaslian = magnet adverse-selection |
| 2026-07-21 | Positioning **memimpin deteksi+jaminan**, bukan provenance | Provenance ramai → kalah frontal |
| 2026-07-21 | AI-slop via **distinctiveness (advisory)**, bukan AI-detection | AI-detection tak reliabel |
| 2026-07-21 | Reframe nilai ke **proteksi-liabilitas + prioritas-IP** | WTP terbukti (Adobe, asuransi IP, first-use) |
| 2026-07-21 | Bootstrap modal **bertahap** (deposit → staking pool) | Hindari telur-ayam modal |
| 2026-07-21 | **v2 G2: Coverage transferable, melekat ke aset (model title insurance)** | Menyelesaikan sisi permintaan: WTP pembeli > WTP kreator; T3 & T4 selesai |
| 2026-07-21 | **v2 G1: Seasoned certificate** (confidence tumbuh seiring bertahan) | Menjawab gap "registry ≠ dunia" secara struktural; moat berdimensi waktu |
| 2026-07-21 | **v2 G3+G4: Kelas bukti admissible + challenger stake** | Adjudikasi tetap dekat-deterministik; griefing mati |
| 2026-07-21 | **v2 G5: Ensemble multi-hash + zona abu-abu** | Menutup arah adversarial-evasion pHash |
| 2026-07-21 | **v2 G6: Coverage = declared value, berjangka 1 thn + perpanjangan** | Ekonomi terdefinisi; tail risk terbatas; revenue berulang |
| 2026-07-21 | **v2 G7: Rename output → "Originality Profile"** | Konsistensi: tak mengklaim "authenticity" di mana pun |
| 2026-07-21 | **v2 D1: Caller rev-share** | Mesin distribusi: agent pemanggil = tenaga penjual |
| 2026-07-21 | **v2 D2: Watch (Living Re-Scan) → pilar bisnis** | Revenue berulang + mekanisme yang membuat guarantee hidup |
| 2026-07-21 | **v2 D3: Reputasi kreator via ERC-8004** | Moat identitas; premi dinamis; tertanam ke rel platform |
| 2026-07-21 | Hindari kata "insurance" di listing ASP | Risiko flag compliance review internal OKX; pakai "guarantee/bond" |
| 2026-07-21 | **v2.1 P1: Commit-reveal + integrasi saat-generasi** | Tanpa ini, first-seen menghadiahi scraper tercepat, bukan kreator sejati — kegagalan mode terburuk |
| 2026-07-21 | **v2.1 P2: Waiting period + plafon reputasi + graph wallet** | Menutup loop fraud self-dealing sebelum kolam Fase 3 dibuka |
| 2026-07-21 | **v2.1 P3: Fraud bond ≠ coverage; sertifikat perpetual, coverage berjangka** | Deposit=declared-value adalah self-insurance yang tak bernilai; dua fungsi harus dipisah |
| 2026-07-21 | **v2.1 P4: Golden Path 4-langkah sebagai aturan penceritaan tunggal** | 16 fitur kehilangan siluet di review 3–5 menit; urutan cerita = keputusan produk |
| 2026-07-21 | **Ide dinyatakan FINAL di level ideation (v2.1)** | Putaran kritik berikutnya = diminishing returns; energi pindah ke Technical Implementation Doc |

---

## 11. GLOSSARY & RESOURCE LINKS

**Glossary:** *First-Seen* = klaim "tak ada near-duplicate lebih tua di registry per timestamp T"; *Perceptual-hash* = sidik jari gambar tahan kompresi/resize; *Ensemble multi-hash* = beberapa algoritma hash paralel — mengelabui satu ≠ mengelabui semua; *Zona abu-abu* = rentang jarak embedding "terlalu dekat untuk disetujui" → advisory/tolak; *Distinctiveness score* = ukuran novel vs derivatif via embedding (advisory); *Originality Profile* = laporan multi-sinyal (pertama/distinctive/deklarasi-AI/seasoning); *Seasoned certificate* = sertifikat yang confidence-nya tumbuh seiring bertahan dari challenge; *Declared value* = nilai aset yang dideklarasikan kreator, dasar coverage & premi; *Transferable coverage* = jaminan melekat ke aset, berpindah bersama kepemilikan; *Bukti admissible* = timestamp on-chain / web-archive / capture ber-C2PA; *Challenger stake* = bond penantang, di-slash bila challenge salah; *Commit-reveal* = hash komitmen privat sebelum karya publik → bukti kepemilikan sejak timestamp komitmen tanpa mengungkap konten; *Fraud bond* = bond kecil-tetap kreator, di-slash saat fraud (bukan coverage); *Waiting period* = jeda aktivasi coverage pasca-terbit (anti klaim self-dealing kilat); *Golden Path* = alur 4-langkah tunggal untuk demo/penjelasan (verify → certify → coverage ikut pembeli → challenge); *Optimistic oracle* = verdict dianggap benar kecuali ditantang dalam jendela waktu; *Discretionary mutual* = skema saling-jamin non-asuransi-teregulasi; *Cachet Watch* = langganan re-scan berkala pemicu klaim otomatis; *ERC-8004* = standar identitas/reputasi agent on-chain; *ASP* = Agent Service Provider di okx.ai; *x402* = standar bayar HTTP-402 stablecoin pay-per-call.

**Sumber problem & preseden:**
- Statistik konten AI: MIT CSAIL + Oxford Internet Institute; Graphite/Originality.ai; Digital Watch Observatory.
- Ketidakandalan AI-detector: OpenAI (penutupan classifier); RAID benchmark.
- Kerentanan perceptual hash: literatur adversarial attack NeuralHash (Apple).
- Premi autentisitas: "In Art We Trust" (Management Science).
- Indemnifikasi IP: Adobe Firefly (Fast Company; Adobe Business).
- Title insurance & exclusion: ARIS Title Insurance (Argo Group) — preseden coverage transferable saat transaksi.
- Model asuransi terdesentralisasi: Nexus Mutual; UMA optimistic oracle.
- Provenance standar: C2PA (`spec.c2pa.org`); Numbers Protocol (ERC-7053).
- First-to-use trademark: World IP Review.
- Identitas agent: ERC-8004.

**Platform:** OKX.AI (`okx.ai`) · x402 (`x402.org`) · OKX Onchain OS.
