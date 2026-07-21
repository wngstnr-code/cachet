# Daftar Gap Kontrak — bahan diskusi B ↔ A

> **Status:** per 22 Jul 2026, setelah B1/B2a/B2b + lima putaran audit.
> **Tujuan:** daftar jujur semua yang BELUM tertutup, supaya keputusannya diambil
> sadar — bukan ditemukan juri.
>
> 153 test hijau, 21/21 mutasi tertangkap, coverage 99.6% baris. Angka itu
> mengukur apakah kode yang ADA benar. Dokumen ini soal yang **tidak ada**.

Tiga dari lima audit menemukan bug di tempat yang sebelumnya dinyatakan aman.
Polanya selalu sama: yang lolos bukan kode yang salah, tapi **cek yang tidak
pernah ditulis**. Karena itu jangan baca dokumen ini sebagai "sisa pekerjaan
kecil".

---

## A. Struktural — tidak bisa ditutup di MVP

### A1. Kolusi operator + resolver 🔴

Owner mint sertifikat ke dirinya sendiri → teman menggugat → resolver memutus
penggugat menang → owner dibayar dari kolam. Semuanya lewat jalur yang sah,
dengan bukti dan jendela liveness lengkap.

Kontrak tidak bisa membedakan resolver jujur dari resolver berkolusi. Itu bukan
masalah implementasi — itu masalah **siapa yang berwenang memutus**.

**Batas kerugian:** saldo vault. Kalau vault berisi 500 USDT, itu batasnya.

**Yang menutupnya:** adjudikasi terdesentralisasi (optimistic oracle / Kleros).
Berminggu-minggu kerja, plus masalah ekonomi: biaya arbitrase bisa melebihi nilai
klaim 100 USDT.

**Opsi yang lebih murah, semuanya butuh orang bukan kode:**
- Resolver dipegang orang **di luar tim** — memecah kolusi tanpa mekanisme baru
- Quorum 2-dari-3 dengan satu pihak luar
- Jaga modal vault tetap kecil → batasi eksposur

**Rekomendasi:** jangan bangun oracle sekarang. Tulis batas ini terus terang di
README dan disclosure listing. Pengakuan yang tepat lebih kuat daripada klaim
"trustless" yang bisa dibongkar dalam dua menit.

### A2. Putusan resolver final, tanpa banding 🟠

Sekali `resolve()` dipanggil, tidak ada mekanisme peninjauan. Salah putus =
permanen.

Konsekuensi dari A1; hilang bersamaan kalau adjudikasi didesentralisasi.

---

## B. Penyalahgunaan parameter — bisa ditutup murah

Semua parameter punya **batas atas**, tapi **tidak satu pun punya batas bawah**.
Terverifikasi di kode.

### B1. `livenessWindow` boleh disetel 0 🔴

```solidity
if (v > MAX_LIVENESS_WINDOW) revert;   // hanya batas atas
```

Jendela liveness adalah **satu-satunya rem publik** terhadap resolver di MVP.
Kalau disetel 0, owner+resolver bisa mint → gugat → putus dalam satu blok, tanpa
jendela pengawasan sama sekali.

Ini melubangi mitigasi utama A1.

**Usulan:** batas bawah `MIN_LIVENESS_WINDOW`. Untuk demo butuh ~30 detik, jadi
misalnya 30 detik sebagai lantai. Produksi tetap 48 jam.

### B2. `premiumBps` boleh disetel 0 🟠

Coverage jadi gratis — sertifikat bernilai 100 USDT tanpa bayar premi. Kalau
digabung A1, biaya menyerang turun drastis.

**Usulan:** batas bawah, atau terima dan dokumentasikan.

### B3. `fraudBondAmount` boleh disetel 0 🟠

Mint tanpa bond. Kreator tidak punya taruhan, dan bounty penantang jadi nol
sehingga insentif menangkap pemalsuan hilang.

### B4. `waitingPeriod` boleh disetel 0 🟡

Coverage aktif seketika. **Sengaja dipakai saat demo** (dipercepat jadi 10 detik,
bukan 0). Di produksi, 0 berarti klaim instan atas karya yang di-mint justru
karena sengketanya sudah diketahui.

### B5. `challengeBond` boleh disetel 0 🟡

Gugatan jadi gratis → spam. Diredam sebagian oleh `openChallengeOf` (satu gugatan
aktif per sertifikat), tapi tetap bisa mengunci sertifikat berulang kali.

> **Catatan:** B1–B5 semuanya butuh owner bertindak jahat, dan semuanya memancarkan
> `ParamChanged` yang terlihat publik. Tapi "terlihat" hanya berarti sesuatu kalau
> ada yang mengawasi.

---

## C. Konsekuensi set-once — trade-off yang sudah diambil

Wiring set-once menutup jalur pengurasan mekanis (owner mengganti ChallengeManager
lalu membayar dirinya). Harganya:

### C1. Kunci resolver hilang = sistem gugatan mati permanen 🔴

`resolver` set-once. Kalau kuncinya hilang:
- Tidak ada gugatan yang bisa diputus, selamanya
- Gugatan terbuka mengunci sertifikatnya (tidak bisa digugat lagi)
- Bond penantang **terjebak di vault permanen**
- Tidak ada jalan pulih selain redeploy seluruh sistem

Ini gap ketersediaan yang nyata, dan konsekuensi langsung dari keputusan set-once.

**Opsi:** backup kunci resolver di tempat terpisah, atau resolver = multisig 2-dari-3,
atau terima risikonya untuk testnet dan tangani sebelum mainnet.

### C2. Salah wiring = redeploy semua 🟠

`GATEWAY_ADDR` harus **final** sebelum deploy. Salah setel berarti deploy ulang
keempat kontrak; sertifikat yang sudah terbit jadi yatim.

Diterima sadar, konsisten dengan alasan menolak proxy (§5.0): redeploy murah
selama belum ada pengguna nyata.

### C3. Tidak ada pause / emergency stop 🟠

Terverifikasi: nol mekanisme jeda. Kalau bug ditemukan setelah deploy, tidak ada
yang bisa dihentikan. Satu-satunya jalan adalah redeploy, dan sertifikat lama
tertinggal.

**Trade-off:** menambah `Pausable` memberi owner kuasa membekukan payout —
mengembalikan sebagian kekuasaan yang baru saja kita cabut. Sengaja tidak dipasang.

---

## D. Batasan yang diterima & sudah didokumentasikan

| # | Batasan | Catatan |
|---|---|---|
| D1 | Coverage dibatasi saldo vault → `PartialPayout` | Sengaja: revert akan mengunci klaim (§9.3) |
| D2 | Modal operator di vault **tidak bisa ditarik** | Tidak ada fungsi withdraw, termasuk untuk owner. Itu yang membuat "collateralized" berarti sesuatu. |
| D3 | `commit()` bisa di-front-run | Hanya griefing gas; hash tetap tercatat, hanya kreator yang tahu salt |
| D4 | Tidak ada dedup pHash on-chain | Biaya O(n). Penyaringan di gateway (§9.5) — kontrak percaya gateway sudah menyaring |
| D5 | Kontrak tidak memverifikasi isi commitment | Hanya membuktikan "hash X ada sejak T", bukan "X berasal dari karya Y" |
| D6 | `mintCertificate` bisa buat 2 sertifikat untuk 1 entryId | Tidak dijamin (tanpa bond → tanpa coverage), tapi tetap membingungkan di cert page |
| D7 | Registry = korpus Cachet, bukan seluruh internet | Wajib ada di disclosure |

---

## E. Belum terverifikasi — bukan gap, tapi ketidaktahuan

Ini yang paling jujur, dan yang membuatku menolak menyebut kontraknya "clear".

### E1. Belum ada satu baris pun yang jalan di chain sungguhan 🔴

Seluruh 153 test berjalan di EVM lokal Foundry. `make deploy` **belum pernah
dijalankan**. Yang bisa muncul di sana dan tidak muncul di lokal:

- Wiring 11 tautan gagal separuh di tengah broadcast
- Bytecode `shanghai` ditolak zkEVM X Layer
- Verifikasi Sourcify untuk 4 kontrak sekaligus (baru teruji untuk MockUSDT)
- Biaya gas nyata `registerAndMint`
- RPC memutus transaksi di tengah

**Ini prioritas nomor satu.** Bug yang tersisa kemungkinan besar berjenis ini.

### E2. Belum ada mata kedua 🔴

Kelima audit kulakukan sendiri terhadap kodeku sendiri. Tiga kali menemukan bug di
tempat yang sebelumnya kunyatakan aman — dan pola itu tidak berhenti hanya karena
aku kehabisan ide.

Review Dien atas PR #7 adalah lapisan yang **belum pernah ada**.

### E3. Integrasi gateway belum tersentuh 🟠

Masih asumsi sampai H4: rumus premi Dien cocok sampai unit terakhir, encoding
`MintRequest` benar, `_safeMint` menerima alamat Agentic Wallet (kalau itu kontrak,
mint akan **revert**).

---

## F. Sengaja di luar scope (§1.2)

Bukan gap — keputusan produk. Kolam staking Fase-3, rev-share pemanggil, reputasi
ERC-8004, seasoning otomatis on-chain, zkML, C2PA anchoring penuh.

---

## Ringkasan untuk diskusi

**Butuh keputusan kalian berdua:**

| # | Pertanyaan | Biaya |
|---|---|---|
| B1 | Pasang batas bawah `livenessWindow`? | ~5 baris |
| B2–B5 | Batas bawah parameter lain? | ~15 baris |
| C1 | Cadangan kunci resolver / multisig? | prosedur, bukan kode |
| A1 | Siapa yang pegang resolver — bisa orang luar? | mencari orang |

**Tidak butuh keputusan, butuh dikerjakan:**

- **E1 deploy testnet** — prioritas tertinggi
- **E2 review Dien** atas PR #7
- **A1 + D-list masuk README** dan disclosure listing

**Saranku soal urutan:** B1 layak dikerjakan sekarang (murah, menutup lubang di
mitigasi utama). Sisanya bahas setelah deploy — karena E1 kemungkinan besar
menghasilkan temuan yang mengubah prioritas.
