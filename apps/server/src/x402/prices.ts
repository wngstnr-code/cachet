/**
 * Harga x402 v2 per endpoint (§1.3). String USD sengaja dipakai agar SDK OKX
 * memilih aset settlement resmi untuk network yang aktif (USD₮0 di X Layer),
 * bukan MockUSDT milik kontrak Cachet. Endpoint yang tidak terdaftar = GRATIS.
 */

export const PRICES: Record<string, string> = {
  "POST /v1/verify": "$0.02",
  "POST /v1/commit": "$0.01",
  "POST /v1/mint": "$0.50", // premi on-chain tetap transaksi terpisah
  "POST /v1/watch": "$0.10", // 30 hari / aset
};

export const DESCRIPTIONS: Record<string, string> = {
  "POST /v1/verify": "Cachet verify_originality — Originality Profile",
  "POST /v1/commit": "Cachet commit_work — kunci commit-reveal",
  "POST /v1/mint": "Cachet register_and_mint — sertifikat First-Seen",
  "POST /v1/watch": "Cachet watch_subscribe — monitoring 30 hari",
};
