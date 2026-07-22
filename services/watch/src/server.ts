/** HTTP kecil: trigger manual re-scan + dashboard-lite alert (potong-scope §7). */

import Fastify, { type FastifyInstance } from "fastify";

import { sendWebhookAlert } from "./alerts.js";
import type { EngineWatchClient } from "./engine.js";
import { runScan } from "./scan.js";
import type { StateStore } from "./state.js";
import type { Subscription } from "./types.js";

export interface ServerDeps {
  engine: EngineWatchClient;
  subscriptions: () => Subscription[];
  state: StateStore;
}

export function buildWatchServer(deps: ServerDeps): FastifyInstance {
  const app = Fastify({ logger: false });

  app.get("/healthz", async () => ({ status: "ok", alerts: deps.state.listAlerts().length }));

  // Trigger manual — "re-scan now" (jaring saat cron belum jatuh tempo).
  app.post("/rescan", async () => {
    return runScan({ ...deps, sendAlert: sendWebhookAlert });
  });

  // Dashboard-lite: draft challenge yang sudah terkumpul.
  app.get("/alerts", async () => ({ alerts: deps.state.listAlerts() }));

  return app;
}
