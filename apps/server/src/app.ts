/**
 * Rakitan Fastify — deps disuntik supaya test memakai FakeEngine + StubChain
 * tanpa jaringan/Python. Error handler menyeragamkan { error: { code, message } }.
 */

import Fastify, { type FastifyError, type FastifyInstance } from "fastify";
import rateLimit from "@fastify/rate-limit";

import type { Deps } from "./config.js";
import { AppError } from "./errors.js";
import { registerRoutes } from "./routes.js";
import { registerX402 } from "./x402/plugin.js";

export interface BuildAppOptions {
  uploadLimitBytes?: number;
  rateLimitMax?: number;
}

export async function buildApp(deps: Deps, opts: BuildAppOptions = {}): Promise<FastifyInstance> {
  const app = Fastify({
    logger: false,
    bodyLimit: opts.uploadLimitBytes ?? deps.uploadLimitBytes ?? 15 * 1024 * 1024,
  });

  await app.register(rateLimit, { max: opts.rateLimitMax ?? 120, timeWindow: "1 minute" });

  // SDK OKX: verify di onRequest, settlement di onSend hanya untuk respons sukses.
  registerX402(app, deps.x402);

  app.setErrorHandler((err: FastifyError, _req, reply) => {
    if (err instanceof AppError) {
      return reply.status(err.statusCode).send({ error: { code: err.code, message: err.message } });
    }
    // Body terlalu besar / JSON rusak → Fastify melempar error ber-statusCode.
    if (typeof err.statusCode === "number" && err.statusCode < 500) {
      return reply.status(err.statusCode).send({ error: { code: err.code ?? "BAD_REQUEST", message: err.message } });
    }
    reply.status(500).send({ error: { code: "INTERNAL", message: err.message } });
  });

  registerRoutes(app, deps);
  return app;
}
