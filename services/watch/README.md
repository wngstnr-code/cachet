# @cachet/watch — Watch worker (A4)

Cachet Watch (F11, pilar bisnis): re-scan registry berkala; bila **salinan** aset
yang diawasi MASUK registry (via preseed / re-scan sumber publik — mint menolak
near-dup), kirim **alert** + **draft challenge**.

Spec: `docs/technical_implementation_plan.md` §4-A4.

## Cara kerja

1. Gateway `POST /v1/watch` mencatat subscription (cert_id + fingerprint aset +
   `last_checked` = ukuran corpus saat subscribe) ke store-nya.
2. Worker membaca subscriptions itu (read-only), dan per siklus memanggil engine
   `POST /neardups {entry_id|phashes, since_entry_id}` → entri NEAR_DUP yang lebih
   baru dari titik terakhir.
3. Tiap match → webhook alert + draft challenge (bukti: entri diawasi + timestamp)
   → dicatat ke dashboard-lite. Titik periksa dimajukan (tak dobel-alert).

Worker punya **state sendiri** (`data/watch.json`) — tak menulis ke file gateway.

## Jalankan

```bash
pnpm install
pnpm test         # 4 test — alert menyala, titik periksa maju, tak dobel-alert
pnpm typecheck

# Daemon (cron tiap 6 jam + HTTP trigger):
ENGINE_URL=http://localhost:8100 WATCH_PORT=8795 \
  WATCH_SUBSCRIPTIONS_FILE=../../apps/server/data/gateway.json pnpm start

pnpm rescan       # satu siklus manual lalu keluar (potong-scope: "re-scan now")
```

Endpoint worker: `POST /rescan` (trigger manual) · `GET /alerts` (dashboard-lite) ·
`GET /healthz`.

Env: `ENGINE_URL`, `CRON_SCHEDULE` (default `0 */6 * * *`), `WATCH_PORT` (8795),
`WATCH_SUBSCRIPTIONS_FILE` (store gateway), `WATCH_DATA_DIR` (state worker).

## Potong-scope (§7)

Bila cron bermasalah saat demo: pakai `POST /rescan` / `pnpm rescan` sebagai tombol
"re-scan now" manual — jalur nyata yang sama, hanya pemicunya manual.

## Batas jujur (MVP)

Email **tidak** dikirim (tak ada SMTP) — dicatat di log. Webhook dikirim sungguhan.
Draft challenge = bundel bukti siap-pakai, bukan pengajuan otomatis on-chain.
