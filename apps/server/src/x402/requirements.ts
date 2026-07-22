/**
 * Membangun payment requirements x402 dan payload 402.
 *
 * Bentuk mengikuti x402: respons 402 membawa `accepts[]` (satu entri per skema),
 * dikirim sebagai header `PAYMENT-REQUIRED` (base64 JSON, transport v2) DAN di body
 * (v1) supaya klien header-first maupun body-first bisa membacanya. Nama field
 * eksternal (`x402Version`, `PAYMENT-REQUIRED`) HARUS verbatim — interop.
 */

export interface X402Settings {
  network: string; // mis. "eip155:1952" (X Layer testnet)
  asset: string; // alamat token pembayaran (MockUSDT)
  payTo: string; // alamat penerima pembayaran (revenue gateway)
}

export interface PaymentRequirements {
  scheme: string;
  network: string;
  asset: string;
  payTo: string;
  amount: string; // base unit string
  resource: string; // path endpoint
  description: string;
  mimeType: string;
  maxTimeoutSeconds: number;
}

export function buildRequirements(
  s: X402Settings,
  resource: string,
  amount: bigint,
  description: string,
): PaymentRequirements {
  return {
    scheme: "exact",
    network: s.network,
    asset: s.asset,
    payTo: s.payTo,
    amount: amount.toString(),
    resource,
    description,
    mimeType: "application/json",
    maxTimeoutSeconds: 120,
  };
}

/** Entri accepts dengan `amount` (v2) + `maxAmountRequired` (v1) demi kompat. */
function toAccepts(r: PaymentRequirements) {
  return {
    scheme: r.scheme,
    network: r.network,
    asset: r.asset,
    payTo: r.payTo,
    amount: r.amount,
    maxAmountRequired: r.amount,
    resource: r.resource,
    description: r.description,
    mimeType: r.mimeType,
    maxTimeoutSeconds: r.maxTimeoutSeconds,
  };
}

export function paymentRequiredPayload(reqs: PaymentRequirements[]): {
  json: Record<string, unknown>;
  header: string;
} {
  const json = {
    x402Version: 1,
    accepts: reqs.map(toAccepts),
    error: "payment required",
  };
  const header = Buffer.from(JSON.stringify(json)).toString("base64");
  return { json, header };
}
