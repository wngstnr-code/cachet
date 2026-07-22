/**
 * Harga x402 per endpoint (§1.3), base unit 6 desimal. Endpoint yang tak
 * terdaftar = GRATIS (get_certificate, healthz). Untuk /v1/mint ini ONGKOS
 * layanan; premi 2% ditarik terpisah di transaksi mint on-chain, bukan lewat x402.
 */

export const PRICES: Record<string, bigint> = {
  "POST /v1/verify": 20_000n, // 0.02
  "POST /v1/commit": 10_000n, // 0.01
  "POST /v1/mint": 500_000n, // 0.5 (+ premi on-chain terpisah)
  "POST /v1/watch": 100_000n, // 0.1 / 30 hari / aset
};

export const DESCRIPTIONS: Record<string, string> = {
  "POST /v1/verify": "Cachet verify_originality — Originality Profile",
  "POST /v1/commit": "Cachet commit_work — kunci commit-reveal",
  "POST /v1/mint": "Cachet register_and_mint — sertifikat First-Seen",
  "POST /v1/watch": "Cachet watch_subscribe — monitoring 30 hari",
};

export function priceFor(method: string, path: string): bigint | null {
  return PRICES[`${method} ${path}`] ?? null;
}

export function describe(method: string, path: string): string {
  return DESCRIPTIONS[`${method} ${path}`] ?? "Cachet paid endpoint";
}
