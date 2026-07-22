/**
 * Hook Fastify penegak x402. Berjalan di onRequest (SEBELUM body 15 MB diparse)
 * → 402 murah untuk permintaan tanpa bayar. Endpoint gratis dilewati.
 *
 * Alur: harga? tidak → lewat. bypass → lewat. tanpa X-PAYMENT → 402 +
 * PAYMENT-REQUIRED. ada X-PAYMENT → verifikasi facilitator → lewat / 402.
 */

import type { FastifyInstance } from "fastify";

import type { Facilitator } from "./guard.js";
import { describe, priceFor } from "./prices.js";
import { buildRequirements, paymentRequiredPayload, type X402Settings } from "./requirements.js";

export interface X402Options extends X402Settings {
  bypass: boolean;
  facilitator?: Facilitator;
}

export function registerX402(app: FastifyInstance, opts: X402Options): void {
  app.addHook("onRequest", async (req, reply) => {
    const path = req.url.split("?")[0];
    const price = priceFor(req.method, path);
    if (price === null) return; // endpoint gratis
    if (opts.bypass) return; // dev/e2e (X402_BYPASS=1)

    const reqs = buildRequirements(opts, path, price, describe(req.method, path));
    const xPayment = req.headers["x-payment"] as string | undefined;

    if (!xPayment) {
      const { json, header } = paymentRequiredPayload([reqs]);
      reply.header("PAYMENT-REQUIRED", header);
      return reply.code(402).send(json);
    }

    if (!opts.facilitator) {
      // Ada bukti bayar tapi tak ada cara verifikasi → tolak jujur, jangan asal terima.
      const { json, header } = paymentRequiredPayload([reqs]);
      reply.header("PAYMENT-REQUIRED", header);
      return reply.code(402).send({ ...json, error: "no facilitator configured to verify payment" });
    }

    const out = await opts.facilitator.verifyAndSettle(xPayment, reqs);
    if (!out.ok) {
      const { json, header } = paymentRequiredPayload([reqs]);
      reply.header("PAYMENT-REQUIRED", header);
      return reply.code(402).send({ ...json, error: out.reason ?? "payment invalid" });
    }
    if (out.responseHeader) reply.header("PAYMENT-RESPONSE", out.responseHeader);
    // lolos → handler jalan
  });
}
