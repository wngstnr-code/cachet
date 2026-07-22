/** Wrapper tipis middleware x402 v2 resmi OKX untuk Fastify. */

import type { FastifyInstance } from "fastify";
import { paymentMiddleware, x402ResourceServer } from "@okxweb3/x402-fastify";
import type { FacilitatorClient } from "@okxweb3/x402-core/server";
import { ExactEvmScheme } from "@okxweb3/x402-evm/exact/server";

import { buildPaymentRoutes, type X402RouteSettings } from "./routes.js";

export interface X402Options extends X402RouteSettings {
  bypass: boolean;
  facilitator?: FacilitatorClient;
}

export function registerX402(app: FastifyInstance, opts: X402Options): void {
  if (opts.bypass) return;
  if (!opts.facilitator) {
    throw new Error("x402 aktif tetapi OKX facilitator tidak dikonfigurasi");
  }

  const server = new x402ResourceServer(opts.facilitator).register(opts.network, new ExactEvmScheme());
  paymentMiddleware(app, buildPaymentRoutes(opts), server);
}
