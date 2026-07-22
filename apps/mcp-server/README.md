# @cachet/mcp-server — MCP tools (A3 / PR-4)

Surface **MCP** untuk ASP Cachet di okx.ai. Enam tool §3.3 yang **meneruskan** ke
gateway REST (`apps/server`) — seluruh logika ada di gateway; MCP hanya adaptor.

## Tools

| Tool | → gateway | Bayar (x402) |
|---|---|---|
| `verify_originality` | `POST /v1/verify` | 0.02 USDT |
| `commit_work` | `POST /v1/commit` | 0.01 USDT |
| `register_and_mint` | `POST /v1/mint` | 0.5 USDT + premi on-chain |
| `get_certificate` | `GET /v1/cert/:id` | gratis |
| `challenge_certificate` | `POST /v1/challenge` | bond on-chain |
| `watch_subscribe` | `POST /v1/watch` | 0.1 USDT / 30 hari |

## Pembayaran x402

MCP server **tidak** membayar. Bila gateway membalas `402`, tool mengembalikan
payment requirements x402 v2 (header `PAYMENT-REQUIRED`) + hint; **klien
pemanggil** yang menandatangani pembayaran lalu retry dengan header
`PAYMENT-SIGNATURE`. Untuk dev/e2e, jalankan gateway dengan `X402_BYPASS=1` agar
tool langsung lolos.

## Jalankan

```bash
pnpm install
pnpm test        # 5 test — forwarding + passthrough 402 (tanpa gateway/jaringan)
pnpm typecheck

# Sebagai MCP server (stdio), menunjuk ke gateway:
GATEWAY_URL=http://localhost:8787 pnpm start
```

Env: `GATEWAY_URL` (default `http://localhost:${GATEWAY_PORT:-8787}`).

## Desain

- `gateway.ts` — `GatewayClient` (fetch injectable untuk test).
- `tools.ts` — 6 `ToolSpec` (nama, deskripsi, skema zod, handler) — dites langsung
  tanpa transport MCP.
- `server.ts` — daftarkan ke `McpServer`.
- `index.ts` — transport stdio.
