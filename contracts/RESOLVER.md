# Runbook Resolver

Panduan operasional untuk pemegang `RESOLVER_PK`. Baca sebelum memutus gugatan
pertama.

> **Kejujuran yang tidak bisa ditawar.** Di MVP, resolver adalah wallet operator
> — bukan mekanisme terdesentralisasi. Yang diberikan kontrak hanyalah: jendela
> liveness publik sebelum putusan, seluruh bukti & putusan tercatat on-chain,
> dan dana bergerak hanya lewat jalur yang bisa diaudit.
>
> **Jangan pernah menulis "trustless adjudication"** di listing, video, README,
> atau jawaban ke juri. Klaim yang benar: *"aturan mainnya on-chain dan bisa
> diaudit; adjudikasinya masih terpusat, dan itu kelemahan yang kami akui."*

---

## 1. Apa yang sebenarnya diputus

Pertanyaannya **bukan** "apakah karya ini asli" atau "apakah ini dibuat AI".

Pertanyaannya sempit dan hanya itu:

> **Apakah ada salinan yang terbukti LEBIH TUA dari `registeredAt` sertifikat ini?**

Kalau ya → penantang menang, sertifikat dicabut, pemegang dibayar.
Kalau tidak terbukti → penantang kalah, bond-nya di-slash.

Beban pembuktian ada di **penantang**. Ragu berarti gugatan ditolak — bukan
karena kreator pasti benar, tapi karena sertifikat hanya mengklaim "first-seen
di registry Cachet per timestamp T", dan klaim itu hanya bisa dipatahkan oleh
bukti yang lebih tua.

## 2. Tiga kelas bukti yang bisa diterima

| Kelas | Contoh | Kekuatan |
|---|---|---|
| **A — Timestamp on-chain** | tx di chain mana pun yang memuat hash/URI karya, NFT terdahulu, commit Cachet yang lebih tua | Terkuat. Timestamp tidak bisa dipalsukan. |
| **B — Arsip pihak ketiga** | snapshot Wayback Machine, commit Git bertanda tangan, metadata C2PA dengan capture time | Kuat bila arsipnya independen dan bisa diverifikasi ulang siapa pun. |
| **C — Platform berkredibilitas** | post bertanggal di platform besar yang timestamp-nya sulit diedit | Paling lemah. **Tidak cukup sendirian.** |

**Yang TIDAK bisa diterima:**
- Screenshot tanpa sumber yang bisa diverifikasi ulang
- Tanggal file lokal (`mtime` bisa disetel sesuka hati)
- Klaim "saya yang bikin duluan" tanpa artefak
- Kemiripan visual saja, tanpa bukti waktu

## 3. Checklist sebelum memutus

- [ ] `evidenceURI` bisa dibuka dan isinya benar-benar ada
- [ ] Bukti masuk kelas A atau B (kelas C perlu didukung yang lain)
- [ ] Timestamp bukti **lebih tua** dari `registeredAt` entri — cek langsung di chain, jangan percaya klaim di dokumen bukti
- [ ] Kalau sertifikat memakai commit-reveal, bandingkan dengan `commitAt`, bukan `registeredAt` — kreator mungkin sudah mengunci komitmen jauh lebih awal
- [ ] Karya dalam bukti memang karya yang sama, bukan sekadar bergaya mirip
- [ ] Jendela liveness sudah lewat (kontrak menolak kalau belum)
- [ ] `rulingURI` sudah disiapkan: satu halaman berisi alasan, tautan bukti, dan kesimpulan

**Konflik kepentingan:** kalau pemegang sertifikat atau penantang adalah kamu
sendiri, tim, atau pihak terafiliasi — **jangan putuskan**. Catat dan serahkan.
Ini akan terlihat di explorer, dan satu kejadian saja merusak kredibilitas
seluruh sistem.

## 4. Perintah

Baca dulu gugatannya:

```bash
source ../.env

cast call $ADDR_CHALLENGE \
  'getChallenge(uint256)(uint256,address,uint64,uint8,string)' <CHALLENGE_ID> \
  --rpc-url $RPC_URL
# -> certId, challenger, openedAt, status (1=Open), evidenceURI
```

> **Catatan (perilaku gateway saat ini):** gugatan yang dibuka lewat endpoint
> `/v1/challenge` tercatat dengan **address gateway** sebagai `challenger`,
> bukan pihak yang menyerahkan bukti — refund/bounty bond mengalir ke address
> itu. Sebelum memutus, sadari siapa penantang sebenarnya dari `evidenceURI`.

Cek jendela liveness sudah lewat (kontrak tetap menolak kalau belum):

```bash
cast call $ADDR_CHALLENGE 'livenessWindow()(uint64)' --rpc-url $RPC_URL
# resolve baru sah setelah openedAt + livenessWindow
```

Periksa sertifikat yang digugat:

```bash
cast call $ADDR_CERTIFICATE 'certData(uint256)' <CERT_ID> --rpc-url $RPC_URL
cast call $ADDR_CERTIFICATE 'ownerOf(uint256)(address)' <CERT_ID> --rpc-url $RPC_URL
```

Versi terformat (status coverage, umur, survived) tanpa parsing hex — endpoint
baca gratis di gateway, atau cert page:

```bash
curl -s https://api.cachetprotocol.xyz/v1/cert/<CERT_ID> | python3 -m json.tool
# atau buka: https://cachetprotocol.vercel.app/cert/<CERT_ID>
```

Periksa entri registry (di sinilah `registeredAt` dan `commitAt`):

```bash
cast call $ADDR_REGISTRY 'getEntry(uint256)' <ENTRY_ID> --rpc-url $RPC_URL
```

**Putuskan** — penantang menang:

```bash
cast send $ADDR_CHALLENGE \
  'resolve(uint256,bool,string)' <CHALLENGE_ID> true "ipfs://putusan" \
  --rpc-url $RPC_URL --private-key $RESOLVER_PK
```

**Putuskan** — penantang kalah:

```bash
cast send $ADDR_CHALLENGE \
  'resolve(uint256,bool,string)' <CHALLENGE_ID> false "ipfs://putusan" \
  --rpc-url $RPC_URL --private-key $RESOLVER_PK
```

### 4b. Di MAINNET: resolver adalah Safe, bukan EOA

Dua perintah di atas **tidak berlaku di mainnet.** Safe tidak punya private key
tunggal, jadi tidak ada `RESOLVER_PK` yang bisa ditempel ke `--private-key` —
`Deploy.s.sol` bahkan menolak deploy ke chain 196 kalau `RESOLVER_ADDR` bukan
kontrak.

Putusan dieksekusi sebagai transaksi Safe:

1. Buka [app.safe.global](https://app.safe.global) → pilih jaringan **X Layer**
   → buka Safe resolver.
2. **New transaction → Transaction Builder**.
3. Isi:
   - To: alamat `ADDR_CHALLENGE`
   - ABI: tempel ABI `ChallengeManager` dari `packages/contracts-abi/abi/`
   - Method: `resolve`
   - `challengeId` = id gugatan · `challengerWins` = `true`/`false` ·
     `rulingURI` = URI putusan
4. **Create Batch → Send Batch.** Pemilik pertama menandatangani; transaksi
   **belum tereksekusi**.
5. Pemilik kedua membuka Safe yang sama, memeriksa ulang isi transaksi, lalu
   **Confirm & Execute**. Baru pada titik ini putusan mendarat on-chain.

Yang berubah secara operasional: **putusan butuh dua orang dan tidak instan.**
Itu memang tujuannya — tapi berarti jendela liveness harus disetel cukup panjang
untuk menampung koordinasi manusia, bukan hanya waktu blok.

> Verifikasi `to` dan seluruh argumen di layar penanda tangan **kedua**, bukan
> hanya di layar yang pertama. Penanda tangan kedua adalah satu-satunya
> pemeriksaan yang tersisa sebelum putusan menjadi final dan tak bisa dibatalkan.

## 5. Yang terjadi setelah putusan

**Penantang menang:**
- Sertifikat dicabut permanen (`revoked = true`) — NFT-nya tetap ada sebagai catatan publik, tidak dibakar
- Bond penantang dikembalikan, plus bounty (fraud bond kreator + 50% premi)
- **Pemegang saat ini** menerima `declaredValue` — dibaca saat resolve, jadi kalau aset sudah dijual, pembelilah yang dibayar
- Dana kurang → dibayar sebagian + event `PartialPayout`. Klaim tidak pernah terkunci.
- Coverage tidak berlaku (masih masa tunggu / kedaluwarsa / tidak insurable) → **tidak ada pembayaran**, tapi pencabutan dan bounty tetap jalan. Event `ClaimSkippedNoCoverage` menjelaskan alasannya di cert page.

**Penantang kalah:**
- `challengesSurvived` naik satu — ini jadi rekam jejak sertifikat, terlihat di cert page
- Bond penantang: 50% ke pemegang sertifikat, 50% tinggal di vault
- Sertifikat tetap hidup, coverage tetap berlaku

**Tidak bisa dibatalkan.** Putusan bersifat final di MVP — tidak ada banding.
Karena itu jangan memutus tanpa menyelesaikan checklist §3.

## 6. Keamanan kunci

- `RESOLVER_PK` **wajib** terpisah dari deployer dan gateway (invariant §9.6) —
  `Deploy.s.sol` menolak jalan kalau ketiganya tidak berbeda
- Alamat resolver **terkunci sejak deploy** (set-once). Tidak bisa diganti tanpa
  redeploy seluruh sistem. Itu disengaja: identitas pemutus harus publik dan
  tetap.
- Testnet-only. Kalau nanti pindah mainnet, buat kunci baru — jangan pernah
  pakai ulang kunci yang pernah muncul di terminal atau chat.

### Mainnet: Safe multisig

Di chain 196 resolver adalah **Safe**, dan `Deploy.s.sol` menolak alamat tanpa
bytecode. Yang berubah dibanding testnet:

| | Testnet (1952) | Mainnet (196) |
|---|---|---|
| Resolver | EOA, satu kunci | Safe, M-dari-N |
| Eksekusi putusan | `cast send --private-key` | app.safe.global (§4b) |
| Satu kunci bocor | penyerang menguras vault | belum cukup — perlu M kunci |
| Satu kunci hilang | **gugatan mati permanen (C1)** | Safe tetap jalan selama ≥ M pemilik hidup |

**Safe harus dibuat SEBELUM `make deploy`.** `setResolver` set-once: alamat Safe
harus sudah ada untuk diisikan ke `RESOLVER_ADDR`.

Penyetelan yang disarankan, dan alasannya:

- **Threshold 2-dari-3.** 1-dari-N tidak menambah keamanan apa pun (satu kunci
  tetap cukup untuk memutus). N-dari-N berarti satu kunci hilang mematikan
  sistem — persis risiko C1 yang ingin dihilangkan.
- **Tiga pemilik di tiga tempat berbeda** — mis. hardware wallet, laptop, dan
  kunci cadangan offline. Tiga kunci di satu laptop hanya multisig di atas
  kertas: satu laptop hilang, ketiganya hilang.
- **Jangan jadikan deployer atau gateway sebagai pemilik Safe.** Itu mengembalikan
  penggabungan peran yang dilarang invariant §9.6 lewat pintu belakang.
- **Uji satu putusan di testnet lebih dulu** dengan Safe testnet, sebelum ada
  uang sungguhan yang bergantung padanya.

Yang **tidak** diselesaikan multisig, dan harus tetap diakui apa adanya: pemutus
tetap operator Cachet, bukan mekanisme terdesentralisasi. Multisig menghapus
titik gagal *kunci tunggal* (C1) — ia tidak menghapus *adjudikasi tersentralisasi*
(A1). Jangan menulis "trustless" karena sudah memakai Safe.
