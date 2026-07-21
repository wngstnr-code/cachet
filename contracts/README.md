# Cachet Contracts (Person B)

Kontrak Solidity untuk Cachet di **X Layer Testnet (chainId 195)**.
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

## Isi saat ini (B1 — selesai)

| Kontrak | Status | Catatan |
|---|---|---|
| `MockUSDT` | ✅ | ERC-20 **6 desimal**, faucet publik, cap 1jt/panggilan |

**Kenapa mock, bukan USDT asli:** di testnet tidak ada deployment Tether resmi, dan
test butuh kontrol penuh atas saldo tiap wallet. Kalau flag §10 diputar ke mainnet
(196), `payToken` diganti USDT asli — cukup ubah `ADDR_MOCKUSDT` di `.env`, tidak ada
kode yang berubah. Karena itu semua transfer di kontrak inti nanti **wajib memakai
`SafeERC20`**: sebagian deployment USDT tidak mengembalikan `bool` pada `transfer`.

## Berikutnya (B2)

`CachetRegistry` · `CachetCertificate` (dengan `registerAndMint` atomik dari RFC-001)
· `CachetVault` · `ChallengeManager` + `Deploy.s.sol` (wiring lengkap + assert).

## Yang mudah bikin tersandung

- **Gas di X Layer = OKB, bukan ETH.** Saldo ETH dari testnet lain tidak berguna.
  Faucet: `okx.com/xlayer/faucet`.
- **6 desimal, bukan 18.** Seluruh angka Cachet (`MAX_DECLARED_VALUE = 100e6`,
  bond `5e6`/`10e6`, premi `declaredValue * 200 / 10000`) bergantung pada ini.
- **RPC testnet pernah berubah** — verifikasi di `web3.okx.com/xlayer`, jangan
  hardcode, semua lewat `.env`.
- **String literal Solidity harus ASCII.** Em dash / karakter Unicode di dalam
  `"..."` bikin compile gagal; pakai `unicode"..."` kalau memang perlu.
