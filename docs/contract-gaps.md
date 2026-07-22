# Daftar Gap Kontrak — bahan diskusi B ↔ A

> **Status:** per 22 Jul 2026, setelah B1/B2a/B2b + **enam** putaran audit.
> Audit keenam memverifikasi ulang seluruh daftar ini terhadap kode terkini
> (pasca commit `f1a54b4`, lantai parameter): **kategori B sudah tertutup**,
> dan ditemukan gap baru — kategori **G**. Tindak lanjut: **SELURUH kategori G
> tertutup** (G1 snapshot liveness · G2 coverage@openedAt · G3 earmark bond ·
> G4 komentar · G5 Ownable2Step + renounce dimatikan, tanpa residual;
> 169 test hijau; G2 lewat delegasi Dien→B). E1 tuntas: deploy final
> terverifikasi + golden path on-chain. Sisa terbuka murni non-kode:
> A1/A2 (struktural), C1 (prosedural), D-list (disclosure — kini tertulis di
> `contracts/README.md`), E2 (review PR #14).
> **Tujuan:** daftar jujur semua yang BELUM tertutup, supaya keputusannya diambil
> sadar — bukan ditemukan juri.
>
> 169 test hijau (pasca G1+G2+G3+G5), 21/21 mutasi tertangkap, coverage 99.6% baris.
> Angka itu mengukur apakah kode yang ADA benar. Dokumen ini soal yang
> **tidak ada**.

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

### G1. Perubahan `livenessWindow` berlaku surut ke gugatan terbuka — ✅ TERTUTUP

`resolve()` dulu menghitung jendela dengan nilai `livenessWindow` **saat
resolve**, bukan nilai saat gugatan dibuka:

```solidity
uint64 requiredUntil = c.openedAt + livenessWindow;   // nilai SEKARANG (LAMA)
```

Konsekuensi dua arah, dua-duanya di jalur sah `onlyOwner`:
- **Memperpendek:** gugatan dibuka saat jendela 48 jam → owner menurunkan ke
  lantai 30 detik → resolver langsung memutus. Jendela pengawasan publik yang
  dijanjikan saat gugatan dibuka menguap. Lantai B1 menutup "nol", tapi tidak
  menutup "dikecilkan di tengah jalan".
- **Memperpanjang:** owner menaikkan ke `MAX` 30 hari → putusan tertunda sebulan,
  dan sertifikat terkunci (`openChallengeOf`) selama itu. Digabung G2, ini bisa
  dipakai mendorong putusan melewati akhir coverage.

**Perbaikan (terpasang):** struct `Challenge` kini menyimpan `livenessSnapshot`,
dibekukan ke nilai `livenessWindow` saat `challenge()`. `resolve()` memakai
`c.openedAt + c.livenessSnapshot`. Perubahan parameter hanya berlaku untuk
gugatan berikutnya. Murni internal `ChallengeManager` — **tidak menyentuh
interface beku §3.1** (`getChallenge`/`IChallengeManager` tak berubah), jadi
tanpa koordinasi lintas-orang. Dua test regresi (perpendek & perpanjang di
tengah gugatan) hijau.

### G2. Jendela coverage dinilai saat RESOLVE, bukan saat gugatan dibuka — ✅ TERTUTUP

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

**Perbaikan (terpasang):** kelayakan coverage kini dinilai terhadap momen
gugatan DIBUKA. Tanpa menyentuh `settleChallengeWon` (beku §3.1): Vault
mencatat `challengeOpenedAt[challengeId]` di `collectChallengeBond` (dipanggil
sinkron dari `challenge()`, jadi `block.timestamp` di sana = openedAt) dan
`_coverageApplies` membandingkan `openedAt` dengan jendela coverage —
`openedAt == 0` (bond tak pernah ditarik) otomatis gagal, konsisten dengan
"tidak ada bond, tidak ada coverage".

Dua lubang tertutup sekaligus:
- **ekor:** gugatan sah di ujung coverage tidak lagi gugur karena liveness
  mendorong resolve melewati `coverageEnd`;
- **tepi depan (efek samping yang diterima sadar):** gugatan yang dibuka
  SELAMA masa tunggu tidak berhak klaim meski resolve mendarat setelah
  coverage aktif — masa tunggu jadi benar-benar berarti.

Konsekuensi demo: `DemoFlow` dipecah — babak 3 (gugatan) jadi fase
`make demo-challenge` yang menolak jalan sebelum coverage aktif. Total durasi
demo tetap 40 detik (10 tunggu + 30 liveness, kini berurutan). **Keputusan
didelegasikan Dien ke B** (persetujuan lisan, 22 Jul) — tidak menyentuh §3.1
jadi tanpa changelog freeze. +2 test regresi (ekor & tepi depan), golden path
diverifikasi ulang end-to-end di testnet dengan semantik baru.

### G3. Bond penantang tidak dipisahkan dari kolam klaim — ✅ TERTUTUP

Pembukuan vault agregat: satu saldo untuk modal, premi, fraud bond, dan
challenge bond. `_pay` membayar sebatas saldo. Akibatnya klaim besar sertifikat
LAIN bisa memakan dana yang "seharusnya" menjamin bond gugatan yang masih
terbuka — dan refund bond penantang (uangnya sendiri, gugatan MENANG) bisa
terbayar sebagian atau nol. `BondRefunded` jujur memancarkan jumlah aktual,
tapi tidak ada padanan `PartialPayout` untuk bond, jadi cert page tidak bisa
menjelaskan kenapa refund kurang.

Ini beda dari D1 (klaim berplafon saldo — diterima sadar): yang berisiko di
sini adalah **uang milik penantang**, bukan janji coverage operator.

**Perbaikan (terpasang):** earmark. `reservedChallengeBonds` menghitung total
bond gugatan yang masih terbuka; klaim & bounty dibayar lewat `_payUnreserved`
(saldo di luar cadangan), sedangkan refund/slash bond melepas cadangan dulu.
Invariant: saldo vault ≥ cadangan, karena tiap kenaikan cadangan disertai
transfer masuk sebesar itu dan semua jalur keluar lain dibatasi
saldo-di-luar-cadangan. Refund bond penantang yang menang kini selalu penuh.
+2 test (akuntansi cadangan; skenario "klaim besar cert lain tidak memakan
bond gugatan terbuka").

### G4. Komentar kode basi — bisa menyesatkan disclosure — ✅ TERTUTUP

Dua tempat komentar bertentangan dengan kode terkini:
- `CachetCertificate.setWaitingPeriod`: `@param v 0 diperbolehkan` — padahal
  `MIN_WAITING_PERIOD = 10 seconds` kini menolak 0.
- Header `CachetGoverned`: daftar "KEKUASAAN OWNER" masih menyebut owner bisa
  **mengganti** alamat gateway dan ChallengeManager — sudah tidak benar sejak
  wiring set-once. (Arahnya kebalikan: kode lebih ketat dari komentarnya.
  Tapi README/disclosure yang menyalin komentar ini akan salah dua arah.)

**Perbaikan (terpasang):** kedua komentar diselaraskan dengan kode. NatSpec
`setWaitingPeriod` kini menyatakan lantai 10 detik + plafon 30 hari (0 ditolak).
Header `CachetGoverned` menuliskan kekuasaan owner yang sebenarnya pasca
set-once: owner memilih wiring **sekali saat deploy** lalu terkunci, hanya bisa
menyetel parameter dalam pagar — dan **tidak** bisa mengganti alamat
gateway/resolver/ChallengeManager, mengubah logika, atau menarik dana. Hanya
komentar; nol perubahan perilaku, 162 test tetap hijau.

### G5. `Ownable` satu langkah + `renounceOwnership` terbuka — ✅ TERTUTUP (transferOwnership)

Kontrak dulu memakai OZ `Ownable` biasa, bukan `Ownable2Step`. Dua jalur kaki
tertembak: `transferOwnership` ke alamat salah ketik, atau `renounceOwnership`
tak sengaja — dua-duanya membuat SEMUA setter parameter mati permanen
(wiring memang sudah terkunci; yang hilang adalah kemampuan menyetel angka,
termasuk rem darurat `maxDeclaredValue = 0`). Sistem tetap jalan dengan nilai
saat itu — dampaknya sekelas C1, bukan pengurasan dana.

**Perbaikan (terpasang, sebelum deploy):** `CachetGoverned` kini mewarisi
`Ownable2Step`. Satu titik ubah di base → keempat kontrak inti ikut. Pemilik
baru WAJIB `acceptOwnership()`, jadi `transferOwnership` ke alamat salah ketik
hanya menggantung sebagai `pendingOwner` tanpa memutus kendali. +2 test
(transfer dua langkah & accept) plus test `RenounceDisabled`.

**Residual — kini ikut tertutup:** `renounceOwnership` di-override agar revert
(`RenounceDisabled`). Owner tidak pernah perlu melepas kuasa — ia dibutuhkan
selamanya untuk rem darurat `maxDeclaredValue = 0` dan penyetelan parameter.
Serah terima kuasa tetap bisa lewat dua langkah `transferOwnership` +
`acceptOwnership`. G5 tertutup TANPA residual.

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
- ~~G1 snapshot `livenessWindow` per gugatan~~ → ✅ tertutup (internal
  `ChallengeManager`, tanpa ubah §3.1, +2 test regresi).
- ~~G2 coverage dinilai saat gugatan dibuka~~ → ✅ tertutup (Vault mencatat
  `challengeOpenedAt`, tanpa ubah §3.1; DemoFlow dipecah `demo-challenge`;
  delegasi Dien→B; golden path diverifikasi ulang di testnet).
- ~~G4 rapikan komentar basi~~ → ✅ tertutup (komentar saja, nol perubahan
  perilaku).
- ~~G3 earmark bond penantang~~ → ✅ tertutup (`reservedChallengeBonds` +
  `_payUnreserved`; refund penantang menang selalu penuh; +2 test).
- ~~G5 `Ownable2Step`~~ → ✅ tertutup TANPA residual (`Ownable2Step` +
  `renounceOwnership` di-override revert; +3 test).
- ~~E1 deploy testnet~~ → ✅ tuntas: deploy final terverifikasi Sourcify
  4/4 `exact_match`, wiring dikonfirmasi on-chain, golden path penuh
  (mint → jual → coverage menyala → gugat → resolve → payout ke pembeli)
  smoke-test end-to-end dengan semantik final.
- ~~A1 + D-list masuk README~~ → ✅ ada di `contracts/README.md`
  ("Batas yang diakui terbuka") — wajib disalin ke listing/disclosure.

**Seluruh gap level kode TERTUTUP. 169 test hijau.** Sisa terbuka murni
manusia/prosedur:

| # | Pertanyaan | Biaya |
|---|---|---|
| C1 | Cadangan kunci resolver / multisig? | prosedur, bukan kode |
| A1 | Siapa yang pegang resolver — bisa orang luar? | mencari orang |
| E2 | Review Dien atas PR #14 (mata kedua pertama) | review |
