/**
 * Harga x402 v2 per endpoint (§1.3). String USD sengaja dipakai agar SDK OKX
 * memilih aset settlement resmi untuk network yang aktif (USD₮0 di X Layer),
 * bukan MockUSDT milik kontrak Cachet. Endpoint yang tidak terdaftar = GRATIS.
 *
 * KUNCI SENGAJA TANPA HTTP VERB — JANGAN kembalikan ke bentuk "POST /v1/verify".
 *
 * SDK memperlakukan pola tanpa verb sebagai `*` alias semua method
 * (`x402-core/dist/cjs/server/index.js:1787`, dicocokkan di baris 1691), sedangkan
 * pola ber-verb hanya menggate method itu saja. Dengan kunci "POST /v1/verify",
 * sebuah GET tidak pernah menyentuh gate: ia jatuh ke 404 Fastify tanpa header
 * PAYMENT-REQUIRED. Validator resmi OKX memprobe dengan GET, jadi ia menyimpulkan
 * endpoint ini bukan layanan x402 — itulah yang menolak listing ASP #7530:
 *
 *   $ onchainos agent x402-check --endpoint .../v1/verify --agent-id 7530
 *   {"reason":"Endpoint returned HTTP 404 (not 402); not a valid x402 service."}
 *
 * Tanpa verb, method apa pun mendapat tantangan 402 yang sama. Query string tidak
 * mengganggu pencocokan — `normalizePath` membuangnya (server/index.js:1801).
 */

export const PRICES: Record<string, string> = {
  "/v1/verify": "$0.02",
  "/v1/commit": "$0.01",
  "/v1/mint": "$0.50", // premi on-chain tetap transaksi terpisah
  "/v1/watch": "$0.10", // 30 hari / aset
};

export const DESCRIPTIONS: Record<string, string> = {
  "/v1/verify": "Cachet verify_originality — Originality Profile",
  "/v1/commit": "Cachet commit_work — kunci commit-reveal",
  "/v1/mint": "Cachet register_and_mint — sertifikat First-Seen",
  "/v1/watch": "Cachet watch_subscribe — monitoring 30 hari",
};
