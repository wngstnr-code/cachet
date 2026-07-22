# Cachet Contracts (Person B)

Kontrak Solidity untuk Cachet di **X Layer Testnet (chainId 1952)**.
Spec mengikat: `docs/technical_implementation_plan.md` §3.1 (interface freeze, sudah
BEKU sejak RFC-001) dan §5 (workstream B).

## Jalankan

```bash
make help            # daftar perintah
make build
make test
make test-gas
make verify-env      # cek .env root sudah terisi sebelum deploy
make deploy-mockusdt # deploy MockUSDT ke X Layer Testnet
```

> **Jangan jalankan `forge script` telanjang.** Repo ini sepakat memakai **satu
> `.env` di root monorepo**, sedangkan Foundry hanya membaca `.env` dari direktori
> kerjanya. Target `make` sudah menangani itu lewat `-include ../.env`.

Setup pertama kali:

```bash
cp ../.env.example ../.env    # lalu isi DEPLOYER_PK, RESOLVER_ADDR, dst.
git submodule update --init --recursive
```

## Isi saat ini (B1+B2 — selesai & ter-deploy)

| Kontrak | Status | Catatan |
|---|---|---|
| `MockUSDT` | ✅ deployed & verified | ERC-20 **6 desimal**, faucet publik, cap 1jt/panggilan |
| `CachetRegistry` | ✅ deployed & verified | first-seen registry + commit-reveal |
| `CachetCertificate` | ✅ deployed & verified | ERC-721, `registerAndMint` atomik (RFC-001 P1) |
| `CachetVault` | ✅ deployed & verified | bond+premi+payout; bond penantang di-earmark (G3) |
| `ChallengeManager` | ✅ deployed & verified | gugatan publik + liveness snapshot (G1) |

169 test hijau · coverage semantik G2 (dinilai saat gugatan dibuka) ·
`Ownable2Step` + `renounceOwnership` dimatikan (G5).

### Alamat X Layer Testnet (chainId 1952)

Sumber kebenaran untuk consumer: **`packages/contracts-abi/addresses.testnet.json`**.

| Kontrak | Alamat |
|---|---|
| `CachetRegistry` | `0x60BEB9aAF8Bf6066A183F99702A403fAfaD19069` |
| `CachetCertificate` | `0xBB0a921b0C575114B6CbBD7c6E8529855B697043` |
| `CachetVault` | `0x79e959A25aF30e01D0bc9e52C693D92e02C28834` |
| `ChallengeManager` | `0x8BF7551F7e9CB432EbA5fFC21972Bce7f509E664` |
| `MockUSDT` | `0x9ad14e783DCe270BE1214153E940aa686f91fa40` |

Semua ✅ Sourcify `exact_match` — source publik di
`https://repo.sourcify.dev/1952/<alamat>`, explorer di
`https://www.okx.com/web3/explorer/xlayer-test/address/<alamat>`.

**Ambil token gratis** (siapa pun boleh, tanpa izin):

```bash
cast send 0x9ad14e783DCe270BE1214153E940aa686f91fa40 \
  'mint(address,uint256)' <ALAMATMU> 1000000000 \
  --rpc-url https://testrpc.xlayer.tech --private-key $PK
# 1000000000 = 1000 USDT (6 desimal)
```

## Dua aturan yang berlaku untuk semua kontrak

**1. Tidak upgradeable, tapi parameternya bisa disetel.** Tidak ada proxy. Klaim produk
ini adalah jaminan yang bisa dicek tanpa mempercayai kami — kontrak upgradeable berarti
logika payout bisa ditulis ulang setelah sertifikat terjual. Sebagai gantinya, angka
kebijakan (`waitingPeriod`, `maxDeclaredValue`, `fraudBond`, `premiumBps`,
`challengeBond`, `livenessWindow`) jadi variabel `onlyOwner` dengan event
`ParamChanged`. **Parameter boleh berubah, aturan main tidak** — payout selalu ke
`ownerOf(certId)`. Detail: §5.0 technical plan.

**2. Setiap deploy wajib terverifikasi** lewat Sourcify (gratis, tanpa API key). Sudah
otomatis di `make deploy-*`. Cek: `make verify-status ADDR=0x...`.

**Kenapa mock, bukan USDT asli:** di testnet tidak ada deployment Tether resmi, dan
test butuh kontrol penuh atas saldo tiap wallet. Kalau flag §10 diputar ke mainnet
(196), `payToken` diganti USDT asli — cukup ubah `ADDR_MOCKUSDT` di `.env`, tidak ada
kode yang berubah. Karena itu semua transfer di kontrak inti nanti **wajib memakai
`SafeERC20`**: sebagian deployment USDT tidak mengembalikan `bool` pada `transfer`.

## Batas yang diakui terbuka (WAJIB ikut disalin ke listing/disclosure)

Produk ini menjual kepercayaan, jadi klaimnya harus tepat. Yang benar untuk
dikatakan: **"aturan mainnya on-chain dan bisa diaudit; operatornya masih
terpusat."** Jangan pernah menulis "trustless", "insurance/asuransi", atau
"keaslian terjamin".

**Struktural (tidak bisa ditutup kode di MVP):**

- **Adjudikasi tersentralisasi (A1).** Yang memutus menang/kalah adalah
  `resolver` — wallet operator, bukan mekanisme terdesentralisasi. Kontrak
  tidak bisa membedakan resolver jujur dari yang berkolusi; batas kerugian =
  saldo vault. Rem yang ada: jendela liveness publik (min 30 detik, tercatat
  on-chain) + seluruh bukti & putusan on-chain + runbook bukti admissible
  (`RESOLVER.md`). Putusan final, tanpa banding. Roadmap: optimistic oracle.
- **Kunci resolver hilang = sistem gugatan mati permanen (C1).** Wiring
  set-once; tidak ada jalur pemulihan selain redeploy. Mitigasi testnet:
  backup kunci; sebelum mainnet: multisig.
- **Tidak ada pause (C3).** Sengaja — `Pausable` memberi owner kuasa
  membekukan payout, kekuasaan yang justru sudah kami cabut.

**Batasan yang diterima sadar (D-list):**

| Batasan | Konsekuensi jujur |
|---|---|
| Registry = korpus Cachet, bukan seluruh internet | "first-seen" berarti *di registry kami per timestamp T* |
| Coverage berplafon saldo vault | dana kurang → `PartialPayout`, bukan revert |
| Modal operator tidak bisa ditarik | tidak ada fungsi withdraw, termasuk owner |
| Bond penantang di-earmark (G3) | klaim/bounty dibayar dari saldo di luar `reservedChallengeBonds` |
| Kontrak tidak memverifikasi isi karya | hanya "hash X ada sejak T", bukan "X asli" |
| Tier embedding | **advisory**, bukan "AI detector" |
| Owner bisa menyetel parameter | dalam pagar lantai/plafon konstanta, tercatat `ParamChanged` — tapi tidak bisa mengganti wiring, logika, atau menarik dana |

## Yang mudah bikin tersandung

- **Gas di X Layer = OKB, bukan ETH.** Saldo ETH dari testnet lain tidak berguna.
  Faucet: `okx.com/xlayer/faucet`.
- **6 desimal, bukan 18.** Seluruh angka Cachet (`MAX_DECLARED_VALUE = 100e6`,
  bond `5e6`/`10e6`, premi `declaredValue * 200 / 10000`) bergantung pada ini.
- **RPC testnet pernah berubah** — verifikasi di `web3.okx.com/xlayer`, jangan
  hardcode, semua lewat `.env`.
- **String literal Solidity harus ASCII.** Em dash / karakter Unicode di dalam
  `"..."` bikin compile gagal; pakai `unicode"..."` kalau memang perlu.
