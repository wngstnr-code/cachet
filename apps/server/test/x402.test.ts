import { describe, expect, it } from "vitest";

import type { Facilitator, SettleResult } from "../src/x402/guard.js";
import type { PaymentRequirements } from "../src/x402/requirements.js";
import { imgPayload, makeApp } from "./helpers.js";

function decodePaymentRequired(header: string): Record<string, any> {
  return JSON.parse(Buffer.from(header, "base64").toString("utf8"));
}

describe("x402 payment guard", () => {
  it("endpoint berbayar tanpa X-PAYMENT → 402 + header PAYMENT-REQUIRED", async () => {
    const { app } = await makeApp({ verdict: "ORIGINAL", x402: { bypass: false } });
    const res = await app.inject({ method: "POST", url: "/v1/verify", payload: imgPayload });
    expect(res.statusCode).toBe(402);

    const header = res.headers["payment-required"] as string;
    expect(header).toBeTruthy();
    const decoded = decodePaymentRequired(header);
    expect(decoded.x402Version).toBe(1);
    const accept = decoded.accepts[0];
    expect(accept.scheme).toBe("exact");
    expect(accept.network).toBe("eip155:1952");
    expect(accept.amount).toBe("20000"); // verify = 0.02 USDT
    expect(accept.maxAmountRequired).toBe("20000"); // kompat v1
    expect(accept.payTo).toMatch(/^0x/);
  });

  it("harga benar per endpoint (§1.3)", async () => {
    const { app } = await makeApp({ x402: { bypass: false } });
    const price = async (url: string, payload: unknown) => {
      const r = await app.inject({ method: "POST", url, payload: payload as object });
      return decodePaymentRequired(r.headers["payment-required"] as string).accepts[0].amount;
    };
    expect(await price("/v1/verify", imgPayload)).toBe("20000");
    expect(await price("/v1/commit", {})).toBe("10000");
    expect(await price("/v1/mint", {})).toBe("500000");
    expect(await price("/v1/watch", {})).toBe("100000");
  });

  it("get_certificate GRATIS → tak pernah 402", async () => {
    const { app } = await makeApp({ x402: { bypass: false } });
    const res = await app.inject({ method: "GET", url: "/v1/cert/999" });
    // 404 (cert tak ada), BUKAN 402 — endpoint gratis lolos guard.
    expect(res.statusCode).not.toBe(402);
  });

  it("facilitator memvalidasi → permintaan lolos ke handler", async () => {
    const seen: string[] = [];
    const facilitator: Facilitator = {
      async verifyAndSettle(xPayment: string, _req: PaymentRequirements): Promise<SettleResult> {
        seen.push(xPayment);
        return { ok: true, responseHeader: Buffer.from(JSON.stringify({ status: "settled" })).toString("base64") };
      },
    };
    const { app } = await makeApp({ verdict: "ORIGINAL", x402: { bypass: false, facilitator } });
    const res = await app.inject({
      method: "POST",
      url: "/v1/verify",
      headers: { "x-payment": "0xPROOF" },
      payload: imgPayload,
    });
    expect(res.statusCode).toBe(200);
    expect(res.json().verdict).toBe("ORIGINAL");
    expect(seen).toEqual(["0xPROOF"]);
    expect(res.headers["payment-response"]).toBeTruthy();
  });

  it("facilitator menolak → 402 lagi dengan alasan", async () => {
    const facilitator: Facilitator = {
      async verifyAndSettle(): Promise<SettleResult> {
        return { ok: false, reason: "insufficient payment" };
      },
    };
    const { app } = await makeApp({ x402: { bypass: false, facilitator } });
    const res = await app.inject({
      method: "POST",
      url: "/v1/verify",
      headers: { "x-payment": "0xBAD" },
      payload: imgPayload,
    });
    expect(res.statusCode).toBe(402);
    expect(res.json().error).toMatch(/insufficient/);
  });

  it("X-PAYMENT ada tapi tanpa facilitator → 402 jujur (tak asal terima)", async () => {
    const { app } = await makeApp({ x402: { bypass: false } }); // facilitator undefined
    const res = await app.inject({
      method: "POST",
      url: "/v1/verify",
      headers: { "x-payment": "0xPROOF" },
      payload: imgPayload,
    });
    expect(res.statusCode).toBe(402);
    expect(res.json().error).toMatch(/facilitator/);
  });

  it("bypass (dev) → langsung lolos tanpa bayar", async () => {
    const { app } = await makeApp({ verdict: "ORIGINAL", x402: { bypass: true } });
    const res = await app.inject({ method: "POST", url: "/v1/verify", payload: imgPayload });
    expect(res.statusCode).toBe(200);
  });
});
