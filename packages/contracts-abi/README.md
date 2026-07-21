# contracts-abi — titik temu #2

Artefak yang diserahkan **Person B → Person A** (§11.2). Person B menulis, Person A
hanya membaca.

> **Statusnya sekarang:** ABI **FINAL**, alamat **belum**.
>
> Kontraknya sudah selesai dan tidak akan berubah interface-nya lagi, jadi
> `abi/*.json` dan `index.ts` bisa dipakai **hari ini** untuk menulis `ChainClient`.
> Yang menyusul saat deploy hanyalah isi `contracts` dan `roles` di
> `addresses.testnet.json` — bentuk dan nama kuncinya tidak berubah lagi.

## Isi

| File | Apa |
|---|---|
| `abi/*.json` | ABI mentah 5 kontrak |
| `index.ts` | ABI ber-`as const` + alamat, siap `import` |
| `addresses.testnet.json` | alamat, chain, peran, parameter default |

Semuanya **di-generate** dari artefak Foundry lewat `cd contracts && make export-abi`.
Jangan edit tangan — perubahan manual akan tertimpa, dan ABI yang menyimpang dari
kontrak adalah bug yang baru muncul di hari integrasi sebagai error encoding yang
tidak menunjuk ke mana pun.

## Pakai

```ts
import { CachetCertificateAbi, addresses } from "@cachet/contracts-abi";
import { createPublicClient, createWalletClient, http } from "viem";

const client = createWalletClient({
  transport: http(addresses.chain.rpcUrl),
  // chainId 1952 — BUKAN 195
});

const { request } = await client.simulateContract({
  address: addresses.contracts.certificate,
  abi: CachetCertificateAbi,
  functionName: "registerAndMint",
  args: [mintRequest],
});
```

`as const` di `index.ts` wajib — itu yang memberi viem inferensi tipe penuh, dan
inferensi itu lapisan yang paling mungkin menangkap salah encoding sebelum sampai
ke chain.

---

# Yang perlu Person A tahu sebelum menulis ChainClient

Enam hal ini berasal dari audit dan tidak akan terlihat dari membaca ABI saja.

## 1. Satu panggilan untuk mint, bukan tiga

Jalur produksi adalah **`Certificate.registerAndMint(MintRequest)`** — satu
transaksi atomik yang melakukan register + mint + tarik dana (RFC-001 P1).

Jangan panggil `Registry.register` atau `Vault.collectOnMint` sendiri; keduanya
menolak pemanggil selain kontrak Certificate.

Urutan `MintRequest` (10 field, cocok persis dengan §3.1):

```ts
{
  to: Address,            // penerima sertifikat
  phashes: [Hex, Hex, Hex, Hex],
  embCommit: Hex,
  revealedCommit: Hex,    // 0x00…0 bila tanpa commit-reveal
  assetURI: string,
  tokenURI_: string,
  declaredValue: bigint,  // base unit, 6 desimal
  fraudBond: bigint,
  premium: bigint,
  insurable: boolean,
}
```

## 2. Premi harus tepat sampai unit terakhir

Vault **memverifikasi sendiri** bond dan premi terhadap `declaredValue` yang
tercatat on-chain. Meleset satu unit → `WrongPremium` → seluruh mint revert.

```ts
const premium = (declaredValue * 200n) / 10000n; // BigInt, floor
```

**Jangan pakai `Number`.** Pembulatan floating point akan meleset pada nilai
ganjil — `33333333` harus menghasilkan `666666`, bukan `666666.66` yang lalu
dibulatkan ke atas.

Lebih aman lagi: baca dari chain, `Vault.quotePremium(declaredValue)`.

`fraudBond` harus persis `Vault.fraudBondAmount()` — jangan hardcode `5e6`,
parameter itu bisa berubah lewat setter.

## 3. Approve SEKALI ke Vault, bukan ke Certificate

Yang menarik dana adalah **Vault**. Wallet gateway cukup `approve` sekali di awal
dengan allowance besar:

```ts
await usdt.write.approve([addresses.contracts.vault, maxUint256]);
```

Allowance `type(uint256).max` tidak berkurang saat dipakai, jadi tidak perlu
approve ulang tiap mint.

Untuk endpoint `challenge_certificate`, instruksi ke penantang juga harus
menyebut **alamat Vault** — approve ke ChallengeManager akan revert.

## 4. Coverage tidak aktif seketika

Sertifikat baru **belum** dijamin. `coverageStart = mintedAt + waitingPeriod`
(default 72 jam). Klaim sebelum itu ditolak on-chain.

Untuk `get_certificate`, jangan simpulkan status dari `certData` saja — panggil
`isCoverageActive(certId)`. Statusnya:

| Kondisi | Tampilkan |
|---|---|
| `revoked` | REVOKED |
| `!insurable` | NOT INSURABLE |
| `now < coverageStart` | PENDING (aktif pada `coverageStart`) |
| `now > coverageEnd` | EXPIRED |
| selain itu | ACTIVE |

## 5. Penerima mint tidak boleh kontrak tanpa `onERC721Received`

`registerAndMint` memakai `_safeMint`. Kalau `to` adalah smart contract wallet
yang tidak mengimplementasi `onERC721Received`, mint **revert**.

Verifikasi alamat penerima sebelum demo — termasuk alamat Agentic Wallet, kalau
itu kontrak.

## 6. Parameter bisa berubah — baca dari chain

`waitingPeriod`, `coverageTerm`, `maxDeclaredValue`, `fraudBondAmount`,
`premiumBps`, `challengeBond`, `livenessWindow` semuanya variabel `onlyOwner`,
bukan konstanta. Nilai di `addresses.testnet.json` hanya **default awal**.

Saat demo, `waitingPeriod` dan `livenessWindow` dipercepat. Kalau gateway
meng-hardcode 72 jam, perhitunganmu akan meleset dari kenyataan chain.

---

## Error yang akan kamu temui

| Error | Artinya |
|---|---|
| `WrongPremium(got, expected)` | rumus premi meleset — pakai `quotePremium` |
| `WrongFraudBond(got, expected)` | pakai `fraudBondAmount()` dari chain |
| `NotGateway(caller, expected)` | wallet salah, atau `GATEWAY_ADDR` saat deploy bukan wallet ini |
| `DeclaredValueTooHigh` | melebihi `maxDeclaredValue` |
| `ERC20InsufficientAllowance` | gateway belum approve ke **Vault** |
| `ERC721InvalidReceiver` | penerima kontrak tanpa `onERC721Received` (poin 5) |
| `AlreadyWired(what)` | wiring sudah terkunci — perlu redeploy, bukan setter |

## Regenerasi

```bash
cd contracts && make export-abi
```

Wajib dijalankan ulang setiap interface kontrak berubah. Kalau ragu apakah file
di sini masih segar, jalankan saja — kalau tidak ada diff, berarti segar.
