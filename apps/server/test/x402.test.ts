import { describe, expect, it } from "vitest";
import {
  decodePaymentRequiredHeader,
  decodePaymentResponseHeader,
  encodePaymentSignatureHeader,
} from "@okxweb3/x402-core/http";
import type { FacilitatorClient } from "@okxweb3/x402-core/server";
import {
  FacilitatorResponseError,
  type PaymentPayload,
  type PaymentRequired,
  type PaymentRequirements,
  type SettleResponse,
  type SupportedResponse,
  type VerifyResponse,
} from "@okxweb3/x402-core/types";

import { PRICES } from "../src/x402/prices.js";
import { buildPaymentRoutes } from "../src/x402/routes.js";
import { imgPayload, makeApp } from "./helpers.js";

const TX_HASH = `0x${"ab".repeat(32)}`;

class FakeFacilitator implements FacilitatorClient {
  verifyCount = 0;
  settleCount = 0;

  constructor(
    private mode: "accept" | "reject" | "verify-error" = "accept",
    private network: "eip155:1952" | "eip155:196" = "eip155:1952",
  ) {}

  async getSupported(): Promise<SupportedResponse> {
    return {
      kinds: [{ x402Version: 2, scheme: "exact", network: this.network }],
      extensions: [],
      signers: { [this.network]: [] },
    };
  }

  async verify(_payload: PaymentPayload, _requirements: PaymentRequirements): Promise<VerifyResponse> {
    this.verifyCount += 1;
    if (this.mode === "verify-error") throw new FacilitatorResponseError("broker unavailable");
    if (this.mode === "reject") return { isValid: false, invalidReason: "insufficient_payment" };
    return { isValid: true, payer: "0x1111111111111111111111111111111111111111" };
  }

  async settle(_payload: PaymentPayload, requirements: PaymentRequirements): Promise<SettleResponse> {
    this.settleCount += 1;
    return {
      success: true,
      status: "success",
      payer: "0x1111111111111111111111111111111111111111",
      transaction: TX_HASH,
      network: requirements.network,
    };
  }
}

function decodeRequired(header: string): PaymentRequired {
  return decodePaymentRequiredHeader(header);
}

function signedHeader(challenge: PaymentRequired): string {
  return encodePaymentSignatureHeader({
    x402Version: 2,
    resource: challenge.resource,
    accepted: challenge.accepts[0],
    payload: { signature: "fake-test-signature" },
  });
}

async function getChallenge(app: Awaited<ReturnType<typeof makeApp>>["app"], url = "/v1/verify") {
  const response = await app.inject({ method: "POST", url, payload: imgPayload });
  expect(response.statusCode).toBe(402);
  const header = response.headers["payment-required"] as string;
  expect(header).toBeTruthy();
  return { response, challenge: decodeRequired(header) };
}

/** Gambar sebagai data: URL — jalur image_url tanpa menyentuh jaringan. */
const IMG_DATA_URL = `data:application/octet-stream;base64,${imgPayload.image_b64}`;

describe("x402 v2 payment guard", () => {
  it("membangun empat route SDK dengan harga yang disepakati", () => {
    const routes = buildPaymentRoutes({
      network: "eip155:1952",
      payTo: "0x1111111111111111111111111111111111111111",
      resourceBase: "https://api.cachet.test",
    }) as Record<string, any>;

    // Kunci TANPA verb — itu yang membuat gate berlaku untuk semua HTTP method.
    // Menambahkan kembali "POST " di depan akan membuat GET jatuh ke 404 dan
    // menggagalkan review listing ASP lagi; lihat catatan panjang di prices.ts.
    expect(PRICES).toEqual({
      "/v1/verify": "$0.02",
      "/v1/commit": "$0.01",
      "/v1/mint": "$0.50",
      "/v1/watch": "$0.10",
    });
    expect(Object.keys(routes)).toEqual(Object.keys(PRICES));
    expect(routes["/v1/verify"].resource).toBe("https://api.cachet.test/v1/verify");
    expect(routes["/v1/cert/:id"]).toBeUndefined();
    expect(routes["/v1/challenge"]).toBeUndefined();
  });

  it("tanpa payment → 402 + PAYMENT-REQUIRED x402 v2", async () => {
    const facilitator = new FakeFacilitator();
    const { app, signer } = await makeApp({ x402: { bypass: false, facilitator } });
    const { challenge } = await getChallenge(app);

    expect(challenge.x402Version).toBe(2);
    expect(challenge.resource.url).toBe("https://api.cachet.test/v1/verify");
    const accept = challenge.accepts[0];
    expect(accept.scheme).toBe("exact");
    expect(accept.network).toBe("eip155:1952");
    expect(accept.asset.toLowerCase()).toBe("0x9e29b3aada05bf2d2c827af80bd28dc0b9b4fb0c");
    expect(accept.amount).toBe("20000");
    expect(accept.payTo.toLowerCase()).toBe(signer.address.toLowerCase());
    expect(facilitator.verifyCount).toBe(0);
  });

  it("credential sah → handler lalu settlement + PAYMENT-RESPONSE", async () => {
    const facilitator = new FakeFacilitator();
    const { app, engine } = await makeApp({ verdict: "ORIGINAL", x402: { bypass: false, facilitator } });
    const { challenge } = await getChallenge(app);

    const response = await app.inject({
      method: "POST",
      url: "/v1/verify",
      headers: { "payment-signature": signedHeader(challenge) },
      payload: imgPayload,
    });

    expect(response.statusCode).toBe(200);
    expect(response.json().verdict).toBe("ORIGINAL");
    expect(engine.queryCount).toBe(1);
    expect(facilitator.verifyCount).toBe(1);
    expect(facilitator.settleCount).toBe(1);
    const receipt = decodePaymentResponseHeader(response.headers["payment-response"] as string);
    expect(receipt.success).toBe(true);
    expect(receipt.transaction).toBe(TX_HASH);
  });

  it("credential ditolak → handler dan settlement tidak berjalan", async () => {
    const facilitator = new FakeFacilitator("reject");
    const { app, engine } = await makeApp({ x402: { bypass: false, facilitator } });
    const { challenge } = await getChallenge(app);

    const response = await app.inject({
      method: "POST",
      url: "/v1/verify",
      headers: { "payment-signature": signedHeader(challenge) },
      payload: imgPayload,
    });

    expect(response.statusCode).toBe(402);
    expect(engine.queryCount).toBe(0);
    expect(facilitator.verifyCount).toBe(1);
    expect(facilitator.settleCount).toBe(0);
  });

  it("Broker error → fail closed 502 dan handler tidak berjalan", async () => {
    const facilitator = new FakeFacilitator("verify-error");
    const { app, engine } = await makeApp({ x402: { bypass: false, facilitator } });
    const { challenge } = await getChallenge(app);

    const response = await app.inject({
      method: "POST",
      url: "/v1/verify",
      headers: { "payment-signature": signedHeader(challenge) },
      payload: imgPayload,
    });

    expect(response.statusCode).toBe(502);
    expect(engine.queryCount).toBe(0);
    expect(facilitator.settleCount).toBe(0);
  });

  it("respons bisnis gagal → tidak di-settle", async () => {
    const facilitator = new FakeFacilitator();
    const { app } = await makeApp({ x402: { bypass: false, facilitator } });
    const { challenge } = await getChallenge(app);

    const response = await app.inject({
      method: "POST",
      url: "/v1/verify",
      headers: { "payment-signature": signedHeader(challenge) },
      payload: {},
    });

    expect(response.statusCode).toBeGreaterThanOrEqual(400);
    expect(facilitator.verifyCount).toBe(1);
    expect(facilitator.settleCount).toBe(0);
    expect(response.headers["payment-response"]).toBeUndefined();
  });

  // ── regresi listing ASP #7530 ─────────────────────────────────────────────
  // Listing ditolak dua kali karena keempat path hanya menggate POST: validator
  // resmi OKX memprobe dengan GET, kena 404 Fastify tanpa header PAYMENT-REQUIRED,
  // lalu menyimpulkan "not a valid x402 service". Test di bawah ini yang menjaga
  // supaya itu tidak bisa kambuh diam-diam.
  it.each(["/v1/verify", "/v1/commit", "/v1/mint", "/v1/watch"])(
    "GET %s tanpa payment → 402, bukan 404 (validator listing OKX memprobe pakai GET)",
    async (url) => {
      const facilitator = new FakeFacilitator();
      const { app } = await makeApp({ x402: { bypass: false, facilitator } });

      const response = await app.inject({ method: "GET", url });

      expect(response.statusCode).toBe(402);
      const challenge = decodeRequired(response.headers["payment-required"] as string);
      expect(challenge.x402Version).toBe(2);
      expect(challenge.accepts[0].scheme).toBe("exact");
      expect(challenge.resource.url).toBe(`https://api.cachet.test${url}`);
    },
  );

  it("query string tidak merusak pencocokan route berbayar", async () => {
    const facilitator = new FakeFacilitator();
    const { app } = await makeApp({ x402: { bypass: false, facilitator } });

    const response = await app.inject({ method: "GET", url: "/v1/verify?image_url=https://x.test/a.png" });

    expect(response.statusCode).toBe(402);
    expect(response.headers["payment-required"]).toBeTruthy();
  });

  it("sudah bayar + GET /v1/verify?image_url → 200, sama seperti POST", async () => {
    const facilitator = new FakeFacilitator();
    const { app, engine } = await makeApp({ verdict: "ORIGINAL", x402: { bypass: false, facilitator } });
    const { challenge } = await getChallenge(app);

    const response = await app.inject({
      method: "GET",
      url: `/v1/verify?image_url=${encodeURIComponent(IMG_DATA_URL)}`,
      headers: { "payment-signature": signedHeader(challenge) },
    });

    expect(response.statusCode).toBe(200);
    expect(response.json().verdict).toBe("ORIGINAL");
    expect(engine.queryCount).toBe(1);
    expect(facilitator.settleCount).toBe(1);
    // Hasil berbayar tidak boleh disajikan ulang dari cache bersama ke pemanggil
    // lain yang belum membayar.
    expect(response.headers["cache-control"]).toBe("no-store");
  });

  it("sudah bayar + GET /v1/verify tanpa image_url → 400 dan TIDAK di-settle", async () => {
    const facilitator = new FakeFacilitator();
    const { app } = await makeApp({ x402: { bypass: false, facilitator } });
    const { challenge } = await getChallenge(app);

    const response = await app.inject({
      method: "GET",
      url: "/v1/verify",
      headers: { "payment-signature": signedHeader(challenge) },
    });

    expect(response.statusCode).toBe(400);
    expect(facilitator.verifyCount).toBe(1);
    expect(facilitator.settleCount).toBe(0);
  });

  it.each(["/v1/commit", "/v1/mint", "/v1/watch"])(
    "sudah bayar + GET %s → 405 dan TIDAK di-settle (endpoint tulis, GET harus aman diulang)",
    async (url) => {
      const facilitator = new FakeFacilitator();
      const { app, engine } = await makeApp({ x402: { bypass: false, facilitator } });
      const { challenge } = await getChallenge(app, url);

      const response = await app.inject({
        method: "GET",
        url,
        headers: { "payment-signature": signedHeader(challenge) },
      });

      expect(response.statusCode).toBe(405);
      expect(response.headers.allow).toBe("POST");
      expect(response.json().error.code).toBe("METHOD_NOT_ALLOWED");
      // Tidak ada uang terpotong, dan pipeline-nya tidak pernah mulai berjalan.
      expect(facilitator.settleCount).toBe(0);
      expect(engine.queryCount).toBe(0);
      expect(engine.indexed).toHaveLength(0);
    },
  );

  it("tantangan mainnet menyebut aset USD₮0 X Layer, bukan aset testnet", async () => {
    // Inilah yang dibaca reviewer OKX. Test lain memakai testnet, jadi tanpa test
    // ini aset mainnet tidak pernah ditegaskan di mana pun.
    const facilitator = new FakeFacilitator("accept", "eip155:196");
    const { app } = await makeApp({
      x402: { bypass: false, facilitator, network: "eip155:196" },
    });

    const { challenge } = await getChallenge(app);

    const accept = challenge.accepts[0];
    expect(accept.network).toBe("eip155:196");
    expect(accept.asset.toLowerCase()).toBe("0x779ded0c9e1022225f8e0630b35a9b54be713736");
    expect(accept.amount).toBe("20000");
  });

  it("endpoint gratis tetap melewati payment middleware", async () => {
    const facilitator = new FakeFacilitator();
    const { app } = await makeApp({ x402: { bypass: false, facilitator } });
    const response = await app.inject({ method: "GET", url: "/v1/cert/999" });
    expect(response.statusCode).not.toBe(402);
    expect(facilitator.verifyCount).toBe(0);
  });

  it("x402 aktif tanpa facilitator → aplikasi menolak start", async () => {
    await expect(makeApp({ x402: { bypass: false, facilitator: undefined } })).rejects.toThrow(/facilitator/);
  });

  it("bypass dev → handler berjalan tanpa payment", async () => {
    const { app } = await makeApp({ verdict: "ORIGINAL", x402: { bypass: true } });
    const response = await app.inject({ method: "POST", url: "/v1/verify", payload: imgPayload });
    expect(response.statusCode).toBe(200);
  });
});
