# Daftar Gap Kontrak — bahan diskusi B ↔ A

> **Status:** per 22 Jul 2026, setelah B1/B2a/B2b + **enam** putaran audit.
> Audit keenam memverifikasi ulang seluruh daftar ini terhadap kode terkini
> (pasca commit `f1a54b4`, lantai parameter): **kategori B sudah tertutup**,
> dan ditemukan gap baru — lihat kategori **G**.
> **Tujuan:** daftar jujur semua yang BELUM tertutup, supaya keputusannya diambil
> sadar — bukan ditemukan juri.
>
> 160 test hijau, 21/21 mutasi tertangkap, coverage 99.6% baris. Angka itu
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

## B. Penyalahgunaan parameter — ✅ TERTUTUP (commit `f1a54b4`)

Terverifikasi di kode saat audit keenam: semua parameter kini punya lantai
konstanta (`ParamBelowFloor`), plus batas atas yang sudah ada sebelumnya.

| # | Parameter | Lantai terpasang | Status |
|---|---|---|---|
| B1 | `livenessWindow` | `MIN_LIVENESS_WINDOW = 30 seconds` | ✅ |
| B2 | `premiumBps` | `MIN_PREMIUM_BPS = 10` (0,1%) | ✅ |
| B3 | `fraudBondAmount` | `MIN_FRAUD_BOND = 1e6` (1 USDT) | ✅ |
| B4 | `waitingPeriod` | `MIN_WAITING_PERIOD = 10 seconds` | ✅ |
| B5 | `challengeBond` | `MIN_CHALLENGE_BOND = 1e6` (1 USDT) | ✅ |
| — | `coverageTerm` | `MIN_COVERAGE_TERM = 1 days` | ✅ (bonus) |
| — | `maxDeclaredValue` | plafon `MAX_DECLARED_VALUE_CEILING = 10_000e6`; **sengaja tanpa lantai** (0 = rem darurat penerbitan) | ✅ |

> **Residual yang tetap harus jujur diakui:** lantai mencegah mekanisme
> DIMATIKAN, bukan menjamin nilainya memadai. Owner tetap bisa menyetel semua
> ke lantai (liveness 30 detik, premi 0,1%, bond 1 USDT) — nilai demo, bukan
> nilai produksi. Semua perubahan memancarkan `ParamChanged`, tapi "terlihat"
> hanya berarti sesuatu kalau ada yang mengawasi. Dan lantai TIDAK menutup
> G1/G2 di bawah — perubahan parameter tetap berlaku surut ke gugatan yang
> sedang terbuka.

---

## G. Temuan BARU audit keenam — belum tertutup

Ditemukan saat memverifikasi ulang kategori B. Polanya masih sama dengan lima
audit sebelumnya: bukan kode yang salah, tapi **cek yang tidak pernah ditulis**.

### G1. Perubahan `livenessWindow` berlaku surut ke gugatan terbuka 🟠

`resolve()` menghitung jendela dengan nilai `livenessWindow` **saat resolve**,
bukan nilai saat gugatan dibuka:

```solidity
uint64 requiredUntil = c.openedAt + livenessWindow;   // nilai SEKARANG
```

Konsekuensi dua arah, dua-duanya di jalur sah `onlyOwner`:
- **Memperpendek:** gugatan dibuka saat jendela 48 jam → owner menurunkan ke
  lantai 30 detik → resolver langsung memutus. Jendela pengawasan publik yang
  dijanjikan saat gugatan dibuka menguap. Lantai B1 menutup "nol", tapi tidak
  menutup "dikecilkan di tengah jalan".
- **Memperpanjang:** owner menaikkan ke `MAX` 30 hari → putusan tertunda sebulan,
  dan sertifikat terkunci (`openChallengeOf`) selama itu. Digabung G2, ini bisa
  dipakai mendorong putusan melewati akhir coverage.

**Usulan (murah, ~3 baris):** snapshot `livenessWindow` ke struct `Challenge`
saat `challenge()`, dan `resolve()` memakai nilai snapshot itu. Perubahan
parameter hanya berlaku untuk gugatan berikutnya.

### G2. Jendela coverage dinilai saat RESOLVE, bukan saat gugatan dibuka 🟠

`_coverageApplies` memakai `block.timestamp` saat settle:

```solidity
return block.timestamp >= d.coverageStart && block.timestamp <= d.coverageEnd;
```

Gugatan yang dibuka **di dalam** masa coverage bisa berakhir
`ClaimSkippedNoCoverage` hanya karena jendela liveness mendorong resolve
melewati `coverageEnd`. Contoh: coverage berakhir 1 Des, gugatan sah dibuka
30 Nov, liveness 48 jam → resolve paling cepat 2 Des → pemalsuan terbukti,
sertifikat dicabut, bounty dibayar, **tapi klaim pemegang nol** — padahal fraud
tertangkap di masa coverage. Efeknya: klausul jaminan diam-diam menyusut
sebesar `livenessWindow` di ekor coverage. Digabung G1 (owner memperpanjang
liveness saat gugatan terbuka), penyusutan ini bisa direkayasa.

**Usulan:** nilai kelayakan coverage terhadap `c.openedAt` (saat gugatan
dibuka), bukan saat resolve — butuh mengoper `openedAt` dari ChallengeManager
ke Vault, atau snapshot kelayakan saat `challenge()`.

### G3. Bond penantang tidak dipisahkan dari kolam klaim 🟡

Pembukuan vault agregat: satu saldo untuk modal, premi, fraud bond, dan
challenge bond. `_pay` membayar sebatas saldo. Akibatnya klaim besar sertifikat
LAIN bisa memakan dana yang "seharusnya" menjamin bond gugatan yang masih
terbuka — dan refund bond penantang (uangnya sendiri, gugatan MENANG) bisa
terbayar sebagian atau nol. `BondRefunded` jujur memancarkan jumlah aktual,
tapi tidak ada padanan `PartialPayout` untuk bond, jadi cert page tidak bisa
menjelaskan kenapa refund kurang.

Ini beda dari D1 (klaim berplafon saldo — diterima sadar): yang berisiko di
sini adalah **uang milik penantang**, bukan janji coverage operator.

**Opsi:** earmark bond (saldo terpisah / akuntansi per-tujuan), atau terima dan
dokumentasikan di disclosure + cert page.

### G4. Komentar kode basi — bisa menyesatkan disclosure 🟡

Dua tempat komentar bertentangan dengan kode terkini:
- `CachetCertificate.setWaitingPeriod`: `@param v 0 diperbolehkan` — padahal
  `MIN_WAITING_PERIOD = 10 seconds` kini menolak 0.
- Header `CachetGoverned`: daftar "KEKUASAAN OWNER" masih menyebut owner bisa
  **mengganti** alamat gateway dan ChallengeManager — sudah tidak benar sejak
  wiring set-once. (Arahnya kebalikan: kode lebih ketat dari komentarnya.
  Tapi README/disclosure yang menyalin komentar ini akan salah dua arah.)

**Usulan:** rapikan sebelum README ditulis — disclosure harus disalin dari
kode, bukan dari komentar.

### G5. `Ownable` satu langkah + `renounceOwnership` terbuka 🟡

Kontrak memakai OZ `Ownable` biasa, bukan `Ownable2Step`. Dua jalur kaki
tertembak: `transferOwnership` ke alamat salah ketik, atau `renounceOwnership`
tak sengaja — dua-duanya membuat SEMUA setter parameter mati permanen
(wiring memang sudah terkunci; yang hilang adalah kemampuan menyetel angka,
termasuk rem darurat `maxDeclaredValue = 0`). Sistem tetap jalan dengan nilai
saat itu — dampaknya sekelas C1, bukan pengurasan dana.

**Opsi:** ganti ke `Ownable2Step` (~1 baris per kontrak) sebelum deploy, atau
terima untuk testnet seperti C1.

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

**Sudah selesai sejak versi pertama dokumen ini:**

- ~~B1–B5 batas bawah parameter~~ → ✅ tertutup di commit `f1a54b4`
  (lantai + `ParamBelowFloor`, test lantai hijau).

**Butuh keputusan kalian berdua:**

| # | Pertanyaan | Biaya |
|---|---|---|
| G1 | Snapshot `livenessWindow` per gugatan? | ~3 baris + test |
| G2 | Coverage dinilai saat gugatan dibuka, bukan saat resolve? | ~10 baris + test |
| G3 | Earmark bond penantang, atau cukup didokumentasikan? | sedang / 0 |
| G5 | `Ownable2Step` sebelum deploy? | ~1 baris per kontrak |
| C1 | Cadangan kunci resolver / multisig? | prosedur, bukan kode |
| A1 | Siapa yang pegang resolver — bisa orang luar? | mencari orang |

**Tidak butuh keputusan, butuh dikerjakan:**

- **E1 deploy testnet** — prioritas tertinggi (diverifikasi ulang audit keenam:
  `broadcast/` baru berisi MockUSDT, empat kontrak inti belum pernah menyentuh chain)
- **E2 review Dien** atas PR #7
- **G4 rapikan komentar basi** — sebelum README/disclosure ditulis
- **A1 + D-list masuk README** dan disclosure listing

**Saranku soal urutan:** G1+G2 layak dikerjakan sekarang — murah, satu tema
(snapshot kondisi saat gugatan dibuka), dan menambal sisa lubang di mitigasi
utama A1 yang tidak tertutup oleh lantai parameter. G3/G5 bahas setelah deploy —
karena E1 kemungkinan besar menghasilkan temuan yang mengubah prioritas.
