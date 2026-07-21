# RFC-001 — Perbaikan §3 Interface Freeze sebelum dibekukan

> **Status:** MENUNGGU PERSETUJUAN
> **Diusulkan oleh:** Wangsit (Person B)
> **Perlu persetujuan:** Dien (Person A)
> **Basis:** `technical_implementation_plan.md` §3.1–§3.4
>
> §3 belum boleh dibekukan apa adanya — review menemukan 8 masalah, 3 di antaranya
> membuat alur mint **tidak mungkin dijalankan** seperti tertulis. Dokumen ini berisi
> resolusi konkret untuk tiap poin. Setujui/tolak per poin, lalu §3 dipatch sekali jalan
> dan baru dibekukan.
>
> **Cara pakai:** isi kolom Keputusan di §9. Kalau semua SETUJU, tidak perlu diskusi lagi —
> langsung patch. Yang perlu dibahas cuma yang ditolak.

---

## P1 — 🔴 BLOCKER: `collectOnMint(certId, …)` mustahil dipanggil

**Masalah.** §4-A3.4 menetapkan urutan `approve` → `Vault.collectOnMint` → `Registry.register`
→ `Certificate.mintCertificate`. Tapi `collectOnMint` menerima `certId`, padahal `certId`
baru lahir dari `mintCertificate` di langkah terakhir. Ayam-dan-telur: alur ini tidak bisa
dieksekusi dalam bentuk apa pun.

**Resolusi usulan (Opsi C — atomik).** Pindahkan orkestrasi ke on-chain: satu panggilan
gateway = satu transaksi = register + mint + tarik dana, atau semuanya batal. Ini sekaligus
menyelesaikan **P8**.

```solidity
/// Ditambahkan ke ICachetCertificate. onlyGateway.
struct MintRequest {
    address to;              // penerima cert = kreator saat mint
    bytes32[4] phashes;
    bytes32 embCommit;
    bytes32 revealedCommit;  // 0x0 bila tanpa commit-reveal
    string  assetURI;
    string  tokenURI_;
    uint256 declaredValue;   // base unit, 6 desimal (lihat P5)
    uint256 fraudBond;       // base unit
    uint256 premium;         // base unit
    bool    insurable;
}

/// Atomik: Registry.register → _mint → Vault.collectOnMint(certId, payer=gateway, …)
/// Gateway cukup approve payToken ke Vault SEKALI di awal (allowance besar), lalu
/// panggil ini per mint.
function registerAndMint(MintRequest calldata r)
    external
    returns (uint256 entryId, uint256 certId);
```

`mintCertificate()` dan `Registry.register()` **tetap ada** sebagai fungsi terpisah untuk
unit test B, tapi jalur produksi hanya lewat `registerAndMint`.

**Dampak ke B:** Certificate perlu tahu alamat Registry & Vault → tambah `setRegistry()` dan
`setVault()` (lihat P3). Kerja tambahan ± 1 fungsi orkestrasi + 2 setter.
**Dampak ke A:** justru lebih sederhana — 1 tx, bukan 3. `ChainClient` cukup satu method.
Tidak ada lagi kemungkinan state setengah jadi.

**Opsi B (fallback, kalau P1-C dianggap terlalu banyak scope untuk B):** ganti saja
`collectOnMint(uint256 certId, …)` → `collectOnMint(uint256 entryId, …)` dan panggil
sebelum mint; pembukuan Vault di-key oleh `entryId`. Settlement nanti mencari `entryId`
lewat `Certificate.certData(certId).entryId`. Diff paling kecil, tapi **tidak atomik** —
P8 tetap terbuka.

---

## P2 — 🔴 BLOCKER: `settleChallengeLost` tidak punya `certId`

**Masalah.** Vault harus membayar 50% bond penantang ke `ownerOf(certId)`, tapi signature-nya
`settleChallengeLost(uint256 challengeId, address certHolder)` — tidak ada `certId`. Pemetaan
`challengeId → certId` hidup di ChallengeManager, jadi Vault tidak punya cara memverifikasi
bahwa `certHolder` yang dioper memang pemegang sah. Parameter address yang tidak bisa
diverifikasi = persis pelanggaran invariant §9.1.

**Resolusi usulan.**

```solidity
function settleChallengeLost(
    uint256 certId,          // ← DITAMBAHKAN
    uint256 challengeId,
    address certHolder       // tetap ada untuk event, TAPI divalidasi
) external;
// di dalam: require(certHolder == certificate.ownerOf(certId), "holder mismatch");
```

Selaraskan juga `settleChallengeWon` — sudah punya `certId`, tinggal tambahkan `require`
yang sama.

**Dampak ke B:** butuh P3. **Dampak ke A:** nol (A tidak memanggil fungsi ini).

---

## P3 — 🔴 BLOCKER: Vault tidak punya alamat Certificate

**Masalah.** P2 dan §5-B2.3 sama-sama mensyaratkan Vault memanggil `ownerOf()`. Tapi aturan
wiring §3.1 hanya menyebut `setGateway` dan `setChallengeManager`. Tanpa alamat Certificate,
invariant §9.1 ("payout selalu ke `ownerOf(certId)`") **tidak bisa ditegakkan di dalam Vault** —
hanya bisa dipercayakan ke pemanggil, yang justru yang ingin dihindari.

**Resolusi usulan.** Lengkapi aturan wiring jadi:

| Kontrak | Setter yang wajib ada (`onlyOwner`) |
|---|---|
| CachetRegistry | `setGateway` |
| CachetCertificate | `setGateway`, `setChallengeManager`, `setRegistry`, `setVault` |
| CachetVault | `setGateway`, `setChallengeManager`, `setCertificate` |
| ChallengeManager | `setResolver`, `setCertificate`, `setVault` |

`script/Deploy.s.sol` melakukan seluruh wiring ini berurutan setelah deploy, lalu menulis
`addresses.testnet.json`. **Deploy dianggap gagal kalau ada satu setter pun yang belum dipanggil** —
tambahkan assert di akhir script.

**Dampak ke B:** ± 4 setter tambahan + assert. **Dampak ke A:** nol.

---

## P4 — 🟠 Bug diam: rumus commit tidak konsisten

**Masalah.** §3.1 baris NatSpec menulis `keccak256(abi.encodePacked(phash1, salt, creator))`,
sementara §4-A3.5 menulis `phash0`. Tipe `salt` tidak pernah dideklarasikan. Karena kontrak
**sengaja tidak memverifikasi** isi commitment (§5-B2.1), ketidakcocokan ini tidak akan
revert — commit tetap tercatat, reveal tetap "berhasil", tapi kreator pihak ketiga yang
mengikuti dokumen akan menghitung hash yang berbeda dan komitmennya jadi tidak berguna.
Bug yang tidak akan ketahuan sampai ada pengguna sungguhan.

**Resolusi usulan.** Kunci satu rumus, tulis identik di NatSpec kontrak, di helper gateway,
dan di README:

```
commitHash = keccak256(abi.encodePacked(
    bytes32 phash0,     // hash pertama dari ensemble (imagehash `phash`), BUKAN phash1
    bytes32 salt,       // 32 byte acak dari kreator
    address creator
))
```

Aman dari hash-collision ambiguity karena ketiganya tipe fixed-size (`abi.encodePacked`
hanya berbahaya bila ada ≥2 tipe dinamis).

Gateway **wajib** menyediakan helper yang mengembalikan rumus + contoh, supaya kreator tidak
menghitung sendiri dari prosa.

**Dampak ke B:** perbaiki NatSpec. **Dampak ke A:** pastikan helper `commit_work` pakai
`phash0`.

---

## P5 — 🟠 Presisi: `premium_quote` pakai float

**Masalah.** §3.2 menulis `{"declared_value": 50.0, "premium": 1.0, "fraud_bond": 5.0}` —
float JSON. On-chain semuanya `uint256` 6 desimal. Premi 2% dari nilai ganjil menghasilkan
pecahan yang tidak representable di float biner → jumlah yang di-quote gateway bisa berbeda
beberapa unit dari yang ditarik kontrak. `approve` kurang sedikit = mint revert di tengah demo.

**Resolusi usulan.** Semua nilai uang di JSON jadi **string base unit** (integer, 6 desimal),
dengan nilai tampilan opsional yang jelas-jelas hanya untuk manusia:

```jsonc
"premium_quote": {
  "currency": "USDT",
  "decimals": 6,
  "declared_value": "50000000",     // string base unit — ini yang mengikat
  "premium": "1000000",
  "fraud_bond": "5000000",
  "_display": { "declared_value": "50.00", "premium": "1.00", "fraud_bond": "5.00" }
}
```

Aturan pembulatan premi dikunci: `premium = declaredValue * 200 / 10000` (integer division,
**dibulatkan ke bawah**) — identik di gateway dan di kontrak.

**Dampak ke A:** hitung premi pakai BigInt, jangan `Number`. **Dampak ke B:** pakai rumus
integer yang sama; tambahkan test yang membandingkan hasil untuk nilai ganjil (mis.
`declaredValue = 33333333`).

---

## P6 — 🟠 Jebakan demo: penantang approve ke Vault, bukan ke ChallengeManager

**Masalah.** `challenge()` dipanggil di ChallengeManager, tapi yang melakukan `transferFrom`
adalah `Vault.collectChallengeBond`. Artinya penantang harus `approve` **ke alamat Vault**.
Ini tidak tertulis di mana pun. Intuisi normal orang adalah approve ke kontrak yang dipanggil
→ transaksi revert. Ini jenis kesalahan yang muncul tepat saat rekaman video.

**Resolusi usulan.**
1. Tambahkan ke NatSpec `challenge()`: *"Penantang WAJIB `approve(vault, challengeBond)`
   sebelum memanggil fungsi ini."*
2. Response `challenge_certificate` (§3.3) wajib memuat instruksi eksplisit: alamat Vault +
   jumlah bond + langkah approve.
3. Cert page menampilkan alamat Vault di bagian "cara menggugat".

**Dampak ke A:** perkaya response endpoint. **Dampak ke B:** NatSpec + copy di cert page.

---

## P7 — 🟡 Konsistensi: EIP-712 `phash0` vs `phashes`

**Masalah.** §3.2 menyatakan tanda tangan atas `(asset_sha256, verdict, phashes, timestamp)`
— empat hash. §4-A3.3 mendefinisikan type `Verdict(bytes32 assetSha256,uint8 verdict,bytes32
phash0,uint64 timestamp)` — satu hash. Dampaknya rendah **selama** tidak ada verifikasi
on-chain, tapi begitu roadmap quorum multi-oracle jalan, verdict lama tidak akan bisa
diverifikasi. Murah dikunci sekarang, mahal nanti.

**Resolusi usulan.** Ikat keempat hash lewat satu commitment:

```solidity
Verdict(bytes32 assetSha256,uint8 verdict,bytes32 phashesHash,uint64 timestamp)
// phashesHash = keccak256(abi.encodePacked(phashes[0], phashes[1], phashes[2], phashes[3]))
```

Lebih murah daripada `bytes32[4]` di struct EIP-712, dan tetap mengikat keempatnya.

**Dampak ke A:** sesuaikan definisi type + sertakan `phashes_hash` di §3.2.
**Dampak ke B:** nol sekarang (belum ada verifikasi on-chain).

---

## P8 — 🟡 Robustness: `register` dan `mint` dua transaksi terpisah

**Masalah.** Kalau `register` sukses lalu `mintCertificate` gagal (gas habis, RPC putus,
declared value melebihi plafon), registry berisi entri yatim tanpa sertifikat. Entri itu
akan ikut jadi pembanding di verify berikutnya — bisa memblokir kreator sah dari me-mint
karyanya sendiri (`NEAR_DUP` terhadap entri yatimnya sendiri). Di demo, ini kelihatan seperti
produknya rusak.

**Resolusi usulan.** Selesai otomatis kalau **P1 Opsi C** disetujui (satu tx atomik).
Kalau yang dipilih Opsi B, maka wajib ada kompensasi: fungsi `Registry.voidEntry(entryId)`
`onlyGateway` untuk membersihkan entri yatim + gateway wajib memanggilnya di blok `catch`.

**Dampak:** nol tambahan bila P1-C disetujui.

---

## 9. LEMBAR KEPUTUSAN

| # | Ringkas | Usulan | Keputusan (A & B) |
|---|---|---|---|
| P1 | `collectOnMint` ayam-telur | Opsi C: `registerAndMint()` atomik | ☐ SETUJU ☐ Opsi B ☐ TOLAK |
| P2 | `settleChallengeLost` tanpa `certId` | tambah `certId` + `require ownerOf` | ☐ SETUJU ☐ TOLAK |
| P3 | Vault tak kenal Certificate | lengkapi tabel wiring + assert di deploy | ☐ SETUJU ☐ TOLAK |
| P4 | rumus commit `phash1` vs `phash0` | kunci `phash0` + `salt` = `bytes32` | ☐ SETUJU ☐ TOLAK |
| P5 | `premium_quote` float | string base unit + rumus integer | ☐ SETUJU ☐ TOLAK |
| P6 | approve ke Vault tak tertulis | NatSpec + instruksi di response + cert page | ☐ SETUJU ☐ TOLAK |
| P7 | EIP-712 `phash0` vs `phashes` | `phashesHash` | ☐ SETUJU ☐ TOLAK |
| P8 | register/mint non-atomik | ikut P1-C | ☐ SETUJU ☐ ikut P1-B + `voidEntry` |

**Setelah semua terisi:** patch §3 dalam satu PR + tulis baris changelog di §3 sesuai aturan
§11.4, baru §3 dibekukan dan coding boleh mulai.

**Kalau tidak ada respons sampai H1 sore:** ambil semua "Usulan" sebagai default dan lanjut —
menunggu kesepakatan lebih mahal daripada salah tebak yang bisa dipatch, dan P1 memblokir
semua kerja on-chain B.

---

## 10. Changelog §3 (ditulis SETELAH keputusan, sebelum kode)

<!-- Contoh format, isi saat patch:
- 2026-07-21 · P1 · ICachetCertificate: +registerAndMint(MintRequest), jalur mint jadi atomik · disepakati A+B
-->
