# Deploy Cachet off-chain (A5.3)

Konfig deploy untuk engine + gateway + watch (folder A). Chain sudah di testnet;
service ini yang perlu online di HTTPS publik agar bisa dilisting sebagai ASP okx.ai.

## Isi

| File | Guna |
|---|---|
| `docker-compose.yml` | orkestrasi engine+gateway+watch, satu mesin (VPS) |
| `../../services/engine/Dockerfile` | image engine (Python 3.12) |
| `../../apps/server/Dockerfile` | image gateway (Node 22) — **build context = root repo** |
| `../../services/watch/Dockerfile` | image watch worker |
| `../../apps/mcp-server/Dockerfile` | image MCP (stdio) |

## Prasyarat sebelum deploy (checklist)

- [ ] Root `.env` terisi: `RPC_URL`, `CHAIN_ID=1952`, `ADDR_*` (kontrak testnet),
      `GATEWAY_PK` (wallet gateway ber-OKB + MockUSDT). `CHAIN_MODE` auto=viem.
- [ ] **`X402_BYPASS=0` dan `DEMO_MODE=0`** (wajib untuk yang dilisting, §8/§13).
- [ ] `X402_FACILITATOR_URL` di-set (dari okx.ai) — tanpa ini endpoint berbayar
      balas 402 "no facilitator". Sebelum dapat: jalur darurat = listing gratis (§12).
- [ ] `CERT_PAGE_BASE` = URL cert page dari Wangsit (untuk link hasil mint).

## Jalan cepat (VPS / mesin sendiri)

```bash
cd scripts/deploy
docker compose up --build -d
docker compose logs -f gateway        # cek "listen … chain=viem"
curl http://localhost:8787/healthz
```

Taruh **reverse-proxy HTTPS** (Caddy/nginx/Traefik) di depan `gateway:8787` — okx.ai
memanggil via HTTPS. Engine & watch tak perlu diekspos publik (internal).

**Embedding CLIP nyata (opsional, advisory):** di `docker-compose.yml` service
`engine`, tambah `build.args: { WITH_ML: "1" }` dan set `ENGINE_EMBEDDER=clip`.
Tanpa itu embedding = placeholder; tier pHash (yang dijamin) tetap valid.

## Railway / Fly (alternatif PaaS)

Tiap service = satu app, arahkan ke Dockerfile-nya:

- **engine** → `services/engine/Dockerfile` (root dir `services/engine`).
- **gateway** → `apps/server/Dockerfile` dengan **root directory = repo root**
  (karena butuh `packages/contracts-abi`). Set env: `ENGINE_URL` (URL internal engine),
  `RPC_URL`, `ADDR_*`, `GATEWAY_PK`, `X402_BYPASS=0`, `CERT_PAGE_BASE`, `X402_FACILITATOR_URL`.
- **watch** → `services/watch/Dockerfile`; `ENGINE_URL` + `WATCH_SUBSCRIPTIONS_FILE`
  (perlu berbagi storage dengan gateway — di PaaS tanpa volume bersama, jalankan
  gateway+watch di satu mesin/compose, atau ganti store ke DB bersama nanti).

## Verifikasi pasca-deploy (smoke, §6)

```bash
# tanpa bayar → 402
curl -si -X POST https://<host>/v1/verify -H 'content-type: application/json' -d '{}' | head -1
# get_certificate (gratis) untuk cert yang sudah ada di testnet
curl -s https://<host>/v1/cert/6
```

> Catatan: mint sungguhan di testnet sudah terbukti jalan (cert #6, lihat
> `apps/server/scripts/local-anvil-e2e.sh` untuk rehearsal lokal). Deploy ini hanya
> memindahkan yang sama ke host publik.
