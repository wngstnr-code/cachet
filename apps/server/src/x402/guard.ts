/**
 * Verifikasi pembayaran x402 lewat facilitator (verify → settle).
 *
 * Gateway TIDAK menyelesaikan pembayaran sendiri; ia mendelegasikan ke facilitator
 * (endpoint /verify + /settle) — pola standar x402 di sisi server. Alamat
 * facilitator OKX di-wire saat listing/A5. Untuk dev/e2e pakai X402_BYPASS=1.
 *
 * Bentuk request facilitator mengikuti konvensi x402; bila endpoint OKX berbeda,
 * hanya kelas ini yang berubah — plugin & routes tidak.
 */

import type { PaymentRequirements } from "./requirements.js";

export interface SettleResult {
  ok: boolean;
  responseHeader?: string; // base64 untuk header PAYMENT-RESPONSE
  reason?: string;
}

export interface Facilitator {
  verifyAndSettle(xPayment: string, req: PaymentRequirements): Promise<SettleResult>;
}

export class HttpFacilitator implements Facilitator {
  constructor(private baseUrl: string) {}

  private async call(path: string, body: unknown): Promise<any> {
    const res = await fetch(this.baseUrl + path, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(body),
    });
    if (!res.ok) throw new Error(`facilitator ${path} → ${res.status}`);
    return res.json();
  }

  async verifyAndSettle(xPayment: string, req: PaymentRequirements): Promise<SettleResult> {
    const payload = { x402Version: 1, paymentHeader: xPayment, paymentRequirements: req };
    try {
      const v = await this.call("/verify", payload);
      if (!v.isValid && !v.valid) {
        return { ok: false, reason: v.invalidReason ?? v.reason ?? "payment invalid" };
      }
      const s = await this.call("/settle", payload);
      if (!s.success) return { ok: false, reason: s.error ?? s.reason ?? "settlement failed" };
      const header =
        typeof s.responseHeader === "string"
          ? s.responseHeader
          : Buffer.from(JSON.stringify(s)).toString("base64");
      return { ok: true, responseHeader: header };
    } catch (err) {
      return { ok: false, reason: (err as Error).message };
    }
  }
}
