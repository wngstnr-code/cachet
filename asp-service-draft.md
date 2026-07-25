# ASP Service Setup Draft — okx.ai (lanjutan asp-listing-draft.md)

> Local working file, NOT committed (aturan sama dengan be-tracker.md).
> Jawaban per field form "set up your service". Satu ASP boleh punya beberapa
> service — di bawah ada 4 service berbayar Cachet, urutan = prioritas daftar.
> Semua fakta diambil langsung dari kode (`apps/server/src/routes.ts` untuk field
> request, `apps/server/src/x402/prices.ts` untuk harga) dan patuh bahasa jujur §7.
> Field "Fee" = angka polos (USDT implied), TANPA harga di dalam Name.
> **Description: MAX 200 chars** (dua baris digabung) — semua versi di bawah
> sudah dihitung muat. Field opsional (request_id, salt, asset_uri, email) tak
> muat di 200 chars; endpoint tetap menerimanya — tak wajib disebut di form.

---

## Service 1 — VERIFY (daftar ini duluan; flagship "verify before you buy")

**1. Service name** (24 chars ✓, noun phrase, beda dari nama agent, tanpa harga):

```
Originality Verification
```

**2. Description** (dua baris, 195 chars ✓ dari limit 200):

```
Checks an image against the Cachet first-seen registry; returns a signed Originality Profile for agents and buyers.
Provide: 1. image_b64 or image_url 2. optional declared_value (USDT base units)
```

**3. Type:** `API service (A2MCP)`

**4. Fee:** `0.02`

**5. Endpoint:** `https://api.cachetprotocol.xyz/v1/verify`

---

## Service 2 — MINT

**1. Service name** (27 chars ✓):

```
First-Seen Certificate Mint
```

**2. Description** (dua baris, 193 chars ✓):

```
Registers a work as first-seen, mints a collateral-backed ERC-721 certificate; 2% on-chain premium separate.
Provide: 1. image_b64 or image_url 2. creator_address 3. declared_value (base units)
```

**3. Type:** `API service (A2MCP)`

**4. Fee:** `0.5`

**5. Endpoint:** `https://api.cachetprotocol.xyz/v1/mint`

---

## Service 3 — COMMIT

**1. Service name** (28 chars ✓):

```
Commit-Reveal Timestamp Lock
```

**2. Description** (dua baris, 186 chars ✓):

```
Locks a commit hash before publication so a creator can prove precedence at mint (anti registry-sniping).
Provide: 1. commit_hash, or phash0 + salt + creator address (server computes it)
```

**3. Type:** `API service (A2MCP)`

**4. Fee:** `0.01`

**5. Endpoint:** `https://api.cachetprotocol.xyz/v1/commit`

---

## Service 4 — WATCH

**1. Service name** (24 chars ✓):

```
Registry Copy Monitoring
```

**2. Description** (dua baris, 184 chars ✓):

```
Re-scans the registry for 30 days; a new near-duplicate of your certified work triggers a webhook alert.
Provide: 1. cert_id 2. webhook_url 3. image if cert not minted via this gateway
```

**3. Type:** `API service (A2MCP)`

**4. Fee:** `0.1`

**5. Endpoint:** `https://api.cachetprotocol.xyz/v1/watch`

---

## Catatan (jangan ikut di-paste ke form)

- **Endpoint sudah live & x402-compliant** — terbukti end-to-end: paid verify +
  paid mint sukses dengan settlement USD₮0 nyata (cert #15, sesi #9–10).
- **Fee = angka polos** sesuai instruksi form; nilainya identik dengan
  `prices.ts` ($0.02 / $0.01 / $0.50 / $0.10). Jangan tulis "$" atau "USDT".
- Mint: fee x402 0.5 ≠ premi 2% on-chain — dua hal terpisah, sudah diungkap
  jujur di description (aturan §8 tracker: premi dibaca dari chain, bukan fix).
- Watch: durasi 30 hari per aset disebut di description karena fee field tidak
  bisa memuat "per 30 days".
- Endpoint GRATIS (`GET /v1/cert/:id`, `POST /v1/challenge`, `GET /healthz`)
  tidak perlu didaftarkan sebagai paid service; kalau form menyediakan slot
  "free endpoint", bisa ditambah `GET https://api.cachetprotocol.xyz/v1/cert/:id`.
- Email alert Watch: MVP mencatat alert tapi TIDAK mengirim email sungguhan
  (jujur per A4.2) — karena itu description menyarankan webhook_url.
