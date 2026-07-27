# Framing Cachet — catatan diskusi untuk demo/video/pitch

> Dokumen ini merangkum diskusi soal "apakah Cachet butuh use case yang lebih
> terasa gunanya, atau sudah cukup seperti sekarang" dan hasil investigasi
> kode yang meluruskan beberapa asumsi awal. Ditulis untuk jadi rujukan saat
> menyusun narasi demo/video/pitch — bukan spec teknis (itu ada di
> `technical_implementation_plan.md`) dan bukan keputusan final, masih bisa
> berubah kalau ada fakta baru.
>
> Status implementasi: **belum ada kode yang diubah** dari diskusi ini. Semua
> di bawah adalah temuan (apa yang sudah benar-benar ada di kode) + opsi
> framing (bagaimana menceritakannya), belum eksekusi.

---

## 1. Pertanyaan awal

Apakah Cachet (registry sertifikat first-seen berkolateral untuk karya
digital) butuh use case yang lebih konkret dan gampang di-relate-kan orang
awam, atau mekanismenya sendiri (verify → certify → coverage ikut pembeli →
challenge) sudah cukup sebagai produk?

Jawaban singkat: **mekanismenya sudah kuat dan jujur, tapi belum punya satu
skenario "siapa pakai ini untuk apa" yang konkret.** README dan CTA sudah
menyinggung "agent verify sebelum buy", tapi tidak pernah dilanjutkan jadi
cerita utuh (beli apa, dari siapa, kenapa cert-nya penting).

---

## 2. Lima kandidat use case yang dibahas

Disusun dari yang paling murah (pakai komponen yang sudah ada, tidak perlu
kode baru) ke yang butuh skrip demo baru. Semua tetap tidak menyentuh
`apps/server/` route atau x402 envelope, jadi **tidak memicu review listing
ASP ulang**.

### 2.1 Agentic content marketplace
Agent yang mau beli/lisensi karya (foto stok, aset generatif, dll) query
`/v1/verify` dulu lewat x402 sebelum membayar penjual, menolak transaksi
kalau karya belum `certify` atau statusnya `REVOKED`. Sudah diimplikasikan di
README bagian "For AI agents", tinggal dijadikan skrip demo end-to-end yang
benar-benar jalan.

- Market: agentic commerce masih dini, audiens niche (B2B/infra-agent).
- Relatability orang awam: rendah — kebanyakan orang belum punya agent yang
  belanja untuknya.

### 2.2 Creator-protection / pencegahan pendaftaran ganda (dipilih, lihat §3)
Awalnya dibingkai sebagai "sistem yang memantau karyamu" via `services/watch/`
(cron scan berkala + webhook alert). Setelah dicek kodenya, framing ini
**salah** dan sudah dikoreksi — lihat §4 untuk detail lengkap. Versi yang
benar: registry-gate di `POST /v1/mint` menolak pendaftaran karya yang mirip
dengan yang sudah terdaftar (`NEAR_DUP` → mint gagal), plus mekanisme
challenge yang melindungi pemegang sertifikat kalau sertifikat itu kemudian
terbukti hasil jiplakan.

- Market: sangat besar — siapa pun yang pernah upload karya ke media sosial
  dan karyanya di-repost/dicuri paham masalahnya tanpa perlu dijelaskan.
- Relatability: tinggi, paling visceral dari semua kandidat.
- Diferensiasi dari tools sejenis (Copytrack, Pixsy, reverse image search
  manual): tools itu cuma kirim takedown notice. Cachet, lewat mekanisme
  bond/payout yang sudah ada, punya jalur ke **kompensasi uang nyata** —
  tapi (koreksi penting) bukan ke kreator asli, lihat §4.3.

### 2.3 Challenge-bounty hunter agent
`ChallengeManager` permissionless dan `POST /v1/challenge` memang didesain
agent-friendly — gateway tidak pernah submit transaksi atas nama pemanggil,
cuma mengembalikan instruksi (lihat tabel "Gateway invariants" di README).
Agent otonom bisa menyisir registry, mencari duplikat kuat, mengajukan
challenge sendiri untuk bounty.

- Market: kecil, audiens crypto-native (mirip MEV searcher / bug bounty
  hunter).
- Relatability orang awam: rendah.
- Menarik karena menghidupkan insentif yang sudah dibangun tapi belum pernah
  ditunjukkan sebagai use case (baru dipakai sebagai security invariant).

### 2.4 Rights-clearance / dataset-curation agent
Agent yang mau memakai karya untuk training data atau materi komersial cek
`first-seen timestamp` + status sertifikat dulu sebagai sinyal risiko,
sebelum memakainya.

- Market: institusional (perusahaan AI, agensi), bukan individu.
- Relevansi tematik tinggi saat ini (gugatan Getty vs Stability, NYT vs
  OpenAI) — semua orang di industri AI sudah paham masalahnya tanpa perlu
  dijelaskan.
- Kalah dari §2.2 soal "relate secara personal", menang soal urgensi bisnis.
- Runner-up resmi setelah §2.2.

### 2.5 Buyer-protection layer untuk escrow/marketplace P2P
Agent pembayaran/escrow yang hanya melepas dana penuh (atau menawarkan
proteksi tambahan) kalau item yang dibeli Cachet-certified, memanfaatkan
properti "guarantee follows the holder" yang sudah ada di kontrak.

- Market: pembeli barang digital di marketplace P2P — luas, dan "takut
  ketipu beli barang digital" adalah perasaan yang sangat familiar (mirip
  PayPal buyer protection / chargeback).
- Ini sebenarnya paling dekat dengan **apa yang mekanisme challenge/payout
  SUNGGUH lakukan hari ini** (lihat §4.3) — payout ke pemegang sertifikat
  saat ini, bukan ke kreator asli. Perlu dipertimbangkan ulang apakah ini
  harusnya jadi framing utama, bukan cuma runner-up.

---

## 3. Rekomendasi

**Creator-protection / pencegahan klaim ganda (§2.2), dengan bahasa yang
sudah dikoreksi (§4 dan §5), adalah kandidat terkuat** untuk market size dan
relatability instan. Rights-clearance (§2.4) adalah runner-up yang kuat kalau
target audiensnya B2B/institusional, bukan individu.

**Catatan penting yang mengubah rekomendasi ini (per diskusi §4.3):** setelah
diverifikasi ke kode, mekanisme payout Cachet sebenarnya paling akurat
disebut **buyer-protection** (§2.5), bukan **creator-protection** murni,
karena uang cair ke pemegang sertifikat saat ini, bukan ke kreator asli yang
karyanya dicuri. Framing "creator protection" masih valid untuk BAGIAN
pencegahan-pendaftaran-ganda (gate menolak B mendaftarkan ulang karya A), tapi
TIDAK valid untuk bagian "kreator otomatis dapat kompensasi" — itu klaim yang
harus dibuang dari narasi mana pun.

Rekomendasi konkret: pakai **dua framing terpisah, jangan dicampur**:
1. "Cachet mencegah orang lain mengklaim karyamu di registry kami" (gate,
   §4.2) — cerita untuk kreator.
2. "Kalau sertifikat yang kamu pegang ternyata bohong, uangnya cair ke kamu,
   bukan ke penipunya" (challenge/payout, §4.3) — cerita untuk pembeli.

### 3.1 Urutan cerita final (disepakati)

Dua framing di atas **digabung jadi satu alur, bukan dua video/pitch
terpisah**:

1. **Buka dengan pertanyaan relate**: "pernah nggak kontenmu diduplikasi/
   diklaim orang lain?" — problem dulu, sebelum nama produk disebut (lihat
   §8 untuk kerangka storytelling lengkap).
2. **Baru solusi Cachet muncul.**
3. **Baru dijelaskan mekanismenya, dua lapis, berurutan:**
   - Lapis 1 (kreator): Cachet menolak pendaftar ganda di gate (§4.2) —
     kalau B coba mendaftarkan karya yang mirip karya A yang sudah
     terdaftar, B ditolak, tidak dapat sertifikat.
   - Lapis 2 (pembeli): **kalaupun lolos** dari lapis 1 (mis. copy yang
     cukup termodifikasi hingga lolos deteksi hash — lihat batasan tier
     embedding di §6), dan sertifikat palsu itu sempat berpindah tangan,
     mekanisme challenge **bisa** memberi payout ke pemegang sertifikat
     saat ini (§4.3). Kata "bisa", bukan "otomatis" — tetap perlu pihak
     yang mengajukan challenge dengan bukti, jendela publik 72 jam, dan
     keputusan resolver. Jangan sampai naskah videonya menyiratkan proses
     ini instan/otomatis, itu klaim yang sama yang sudah dikoreksi di §4.1
     dan §4.3.

Urutan ini sudah diverifikasi konsisten secara teknis dengan §4.2 dan §4.3 —
tidak ada revisi pada mekanismenya, hanya urutan penyampaiannya yang dikunci.

---

## 4. Koreksi hasil investigasi kode (penting, jangan diulang kesalahannya)

### 4.1 "Sistem yang memantau karyamu" (Watch) — klaim awal, SALAH

Klaim awal: Cachet punya "sistem yang memantau karyamu" 24/7 lewat
`services/watch/`.

**Realitanya, setelah dicek kode:**

- Bukan real-time. `services/watch/src/index.ts` jalan lewat `node-cron`,
  jadwal default `"0 */6 * * *"` (`services/watch/src/config.ts:25`) — scan
  tiap 6 jam, bukan continuous. Ada juga `POST /rescan` untuk trigger manual
  di antara jadwal (`services/watch/src/server.ts:23`).
- **Lebih penting: di production sekarang, servis ini TIDAK JALAN SAMA
  SEKALI.** Compose file yang benar-benar dipakai di VPS
  (`scripts/deploy/compose.ovh.yml`) cuma mendefinisikan dua servis:
  `engine` dan `gateway`. Servis `watch` cuma ada di
  `scripts/deploy/docker-compose.yml` (dev lokal), tidak pernah di-deploy ke
  production. Hari ini, di `api.cachetprotocol.xyz`, tidak ada apa pun yang
  memindai apa pun secara otomatis.
- Ini cocok dengan `claude.md` §9: `"Watch otomatis → tombol manual"` adalah
  item pertama di daftar buang scope kalau waktu mepet — persis yang
  kelihatan terjadi di deployment saat ini.

**Framing yang benar kalau mau tetap dipakai:** "sistem yang *bisa
dijadwalkan* mengecek ulang registry secara berkala (default tiap 6 jam, atau
dipicu manual)" — dan sebutkan bahwa mengaktifkannya di production butuh satu
langkah deploy tambahan yang belum dilakukan.

### 4.2 Registry-gate menolak pendaftaran ganda — INI BENAR DAN SUDAH JALAN

Usul selanjutnya: bagaimana kalau bukan Watch, tapi gate registrasi itu
sendiri yang jadi mekanisme proteksinya? Ini **benar dan sudah berjalan hari
ini**, tidak seperti Watch.

```ts
// apps/server/src/routes.ts:161-162 — POST /v1/mint
const eng = await engine.query(raw);
if (eng.verdict === "NEAR_DUP") throw errNearDup();
```

Kalau orang B coba mint karya yang mirip dengan yang sudah didaftarkan orang
A, B ditolak langsung di gate: mint gagal, tidak ada NFT diterbitkan. Ini
nyata, sudah ada di kode utama (bukan fitur opsional/belum-deploy seperti
Watch).

### 4.3 Tapi ini BUKAN "orang A otomatis dapat uang" — koreksi kedua

Dua hal yang perlu diluruskan dari usulan "gate-nya menantang B, dan kalau B
gagal membuktikan, otomatis A dapat uangnya":

1. **Penolakan di gate cuma penolakan, bukan transaksi challenge.** B gagal
   dapat sertifikat. Tidak ada bond yang di-slash, tidak ada uang berpindah
   ke siapa pun, karena tidak ada apa pun yang perlu dibayarkan ke A — B
   cuma gagal mint.
2. **Mekanisme challenge yang BENERAN memindahkan uang tidak membayar ke
   "kreator asli".** Kutip README:

   > "If the work is later proven to be a copy, the payout goes to
   > **whoever holds the work now**, not to the creator who lied."

   Alur sebenarnya: B (penipu) lolos gate dengan cara lain (mis. lewat
   gray-zone/embedding yang saat ini masih placeholder — lihat §6), berhasil
   mint, lalu **menjual ke Buyer C**. Baru KEMUDIAN ada yang mengajukan
   challenge dan terbukti itu jiplakan. Uangnya cair ke **C (pemegang
   sertifikat saat ini)**, bukan ke A. Mekanisme ini didesain untuk
   melindungi **pembeli sertifikat** dari penjual yang bohong — bukan untuk
   mengompensasi kreator asli yang karyanya dicuri.

   Selain itu, challenge bukan proses otomatis: perlu pihak ketiga
   mengajukan bond + evidence, jendela liveness publik 72h/48h, dan resolver
   (multisig 2-of-3 di mainnet) yang memutuskan. Tidak ada trigger otomatis
   dari gate ke pembayaran.

**Kesimpulan gabungan §4.2 + §4.3:** benar bahwa registry-gate hari ini sudah
"menjaga" dalam arti *mencegah orang lain mendaftarkan ulang karya serupa* —
itu real, sudah jalan, tidak butuh deploy tambahan. Tapi pitch "orang A
otomatis dapat uang saat B ketahuan mencuri" tidak match dengan kode yang
ada, baik dari sisi "otomatis" maupun dari sisi "siapa yang dibayar".

---

## 5. Bahasa final untuk narasi "registry bukan seluruh internet"

Konteks: klaim "melindungi karyamu dari klaim ganda di dalam ekosistem
Cachet" perlu dipertegas bahwa cakupannya memang masih terbatas ke ekosistem
Cachet sendiri hari ini, TAPI sedang aktif diperbesar — bukan snapshot statis
selamanya. Fakta pendukung: registry produksi berisi ~5.000 entri (sebagian
besar data sintetis bootstrap), sudah disiapkan batch 996 foto Wikimedia
Commons nyata yang siap digabung, dan setiap `mint` yang berhasil otomatis
menambah entri baru ke registry (`apps/server/src/routes.ts:195-197`, komentar
`// Karya ter-mint menyemai registry (§F10)`, via `engine.index()`).

Tiga varian, tergantung konteks pemakaian:

**Untuk README / bagian "Honest limitations" (menambah, bukan mengganti
kalimat yang sudah ada di sana):**

> Cachet baru bisa menahan klaim ganda selama karya pembandingnya juga pernah
> singgah di registry kami — bukan seluruh internet. Registry ini bukan
> snapshot yang berhenti tumbuh: hari ini berisi ~5.000 entri (sebagian besar
> masih data sintetis bootstrap), dan kami sedang aktif menambah data dunia
> nyata (batch pertama 996 foto Wikimedia Commons sudah disiapkan dan tinggal
> digabung). Makin banyak karya masuk, makin luas jangkauan perlindungannya.

**Untuk pitch/demo, lebih ringkas:**

> "Melindungi karyamu dari klaim ganda — di dalam registry Cachet, yang terus
> kami perbesar. Bukan klaim 'mencakup seluruh internet', tapi cakupan nyata
> yang bertambah tiap hari, bukan janji kosong yang berhenti di hari
> peluncuran."

**Untuk FAQ / jawab objection ("apakah ini nyari di seluruh internet?"):**

> Belum, dan kami tidak akan bilang begitu kalau belum benar. Cachet
> mendeteksi klaim ganda di dalam registry-nya sendiri, bukan Google Images.
> Registry-nya sedang tumbuh secara aktif — dari data sintetis bootstrap
> menuju korpus dunia nyata — dan setiap karya yang di-*mint* juga ikut
> memperbesar cakupan itu (setiap mint menyemai registry secara otomatis).

---

## 6. Batasan jujur yang wajib tetap disebut (jangan hilang saat narasi disederhanakan)

Ini pengingat, bukan duplikat — daftar lengkapnya ada di README bagian
"Honest limitations" dan wajib dirujuk, bukan ditulis ulang dari ingatan,
karena angka-angkanya bisa berubah:

- Registry = korpus Cachet sendiri, bukan seluruh internet (§5).
- Coverage berplafon `maxDeclaredValue` on-chain, dibatasi saldo vault —
  jangan hardcode angka plafon di dokumen mana pun (beda per deployment,
  bisa berubah lewat `ParamChanged`). Rujuk parameternya, atau sebutkan
  angka besertaan chain-nya.
- Tier embedding = advisory, dan di deployment live saat ini masih
  `ENGINE_EMBEDDER=fake` (placeholder, bukan CLIP asli) — hanya perceptual
  hash ensemble yang jadi hard claim.
- Adjudikasi masih tersentralisasi (resolver = multisig 2-of-3 di mainnet).
  Multisig menghilangkan risiko kunci tunggal, **bukan** sentralisasinya.
- Watch belum di-deploy di production (§4.1) — kalau mau dipakai sebagai
  klaim produk, harus jujur soal ini atau deploy dulu.
- Payout challenge ke pemegang sertifikat SAAT INI, bukan ke kreator asli
  (§4.3) — jangan campur framing "creator protection" dengan klaim
  "kreator otomatis dibayar".

---

## 7. Status & langkah berikutnya

- Urutan cerita (§3.1) **disepakati** — tidak ada revisi mekanisme, hanya
  urutan penyampaian yang dikunci.
- **Deploy `services/watch/` ke production** (§4.1, supaya klaim "bisa
  dijadwalkan mengecek ulang registry" nyata, bukan cuma ada di kode) —
  **disetujui**, scope Dien sendiri, tidak perlu izin Wangsit. Rencana kerja
  ada di §9.
- **Perbarui README bagian "Honest limitations"** dengan bahasa §5 —
  **disetujui, Wangsit sudah mengizinkan.**
- **Bagikan dokumen ini ke Wangsit** sebagai usul untuk `apps/web/`/demo
  script (§2, §8) — **sudah dilakukan, Wangsit sudah setuju.** Detail
  eksekusi konkret (skrip, halaman) tetap keputusan dan pekerjaan Wangsit.

---

## 8. Konsep video: storytelling, problem dulu baru solusi

Arahan eksplisit dari diskusi ini: video/pitch Cachet dibangun sebagai
**storytelling**, bukan feature walkthrough. Urutan wajib:

1. **Buka dengan problem yang relate** — penonton merasa "ini pernah/bisa
   terjadi ke aku" dan **paham** masalahnya, SEBELUM nama produk disebut.
2. **Baru perkenalkan Cachet sebagai solusi** atas problem itu, mengikuti
   Golden Path yang sudah ada (verify → certify → coverage ikut pembeli →
   challenge).

Alasannya: kalau produk disebut duluan, penonton mengevaluasi fitur secara
teknis dan skeptis. Kalau problem disebut duluan dan penonton keburu relate,
mereka sudah "membeli" masalahnya sebelum solusi ditawarkan — jauh lebih
persuasif untuk audiens awam, bukan cuma audiens teknis/crypto-native.

### 8.1 Relasi dengan video ≤90 detik yang sudah ada

`delivery_implementation_plan.md` §3 sudah punya skrip 4-beat untuk video
submission ASP (≤90 detik, Hook → The Catch → Certify+Guarantee moves →
Challenge payoff), dengan larangan eksplisit keluar dari Golden Path. Skrip
itu **sudah mengikuti pola problem-dulu** (beat 1 "Hook" membuka dengan
masalah konten AI membanjir, baru beat 2 memperkenalkan Cachet) — jadi arahan
storytelling di sini **konsisten**, bukan kontradiksi, dengan yang sudah ada.

Bedanya: dokumen ini untuk framing yang lebih luas dan tidak terikat batas 90
detik/aturan submission ASP — cocok dipakai untuk pitch deck, video
penjelasan lebih panjang, atau materi lain di luar submission listing yang
sudah selesai. Kalau mau merevisi skrip ≤90 detik yang sudah ada, itu tetap
harus ikut batasan §3.3 di `delivery_implementation_plan.md` (larangan
istilah, larangan fitur di luar Golden Path, batas waktu).

### 8.2 Problem mana yang dipakai untuk buka cerita

Berdasarkan §2 dan §3 di dokumen ini, dua kandidat problem paling relate,
**pilih satu untuk buka cerita** (jangan dua-duanya sekaligus di awal, biar
fokus) — baru di bagian solusi tunjukkan produk melindungi dua sisi
sekaligus:

- **Sisi kreator** — karya dicuri/direpost/diklaim ulang orang lain. Framing
  solusi WAJIB pakai versi yang sudah dikoreksi di §4.2 ("gate menolak
  pendaftar kedua"), **bukan** "kreator otomatis dibayar" (itu klaim salah,
  lihat §4.3).
- **Sisi pembeli** — takut beli karya/sertifikat yang ternyata bohong.
  Framing solusi pakai §4.3 ("kalau sertifikat ternyata bohong, uangnya cair
  ke pemegang saat ini").

### 8.3 Kerangka arc (generik, isi bebas sesuai problem yang dipilih)

1. **Problem (relate)** — skenario nyata: seseorang kehilangan karya atau
   uang karena tidak ada cara membuktikan/mempercayai klaim keaslian.
2. **Ketegangan** — kenapa cara yang ada sekarang tidak cukup (DMCA manual
   dan lambat, sertifikat "trust me bro" tanpa jaminan, review manual yang
   tidak scalable untuk agent/AI).
3. **Solusi** — Cachet masuk, ikuti Golden Path.
4. **Bukti** — tunjukkan transaksi on-chain asli (README sudah punya rantai
   lengkap cert #5: mint → jual → challenge → payout ke pembeli), bukan
   mockup atau angka rekaan.
5. **Batasan jujur** disebut singkat, tidak disembunyikan (§6 dokumen ini) —
   ini memperkuat kredibilitas ("kami jujur soal apa yang belum bisa
   dilakukan"), bukan melemahkan pitch.

### 8.4 Status

Ini kerangka/arahan, belum skrip final dan belum ada video/materi baru yang
dibuat dari diskusi ini. Kalau mau dieksekusi jadi video/pitch baru, itu
tetap scope produksi video (`delivery_implementation_plan.md` §3, owner
rekaman: A) atau materi pitch terpisah — bukan sesuatu yang otomatis
mengubah video ≤90 detik yang sudah ada.
