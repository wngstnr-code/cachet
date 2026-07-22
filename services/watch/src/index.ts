/** Entry point Watch worker: cron (tiap 6 jam) + server trigger manual. */

import cron from "node-cron";

import { sendWebhookAlert } from "./alerts.js";
import { loadWatchConfig } from "./config.js";
import { HttpEngineWatchClient } from "./engine.js";
import { runScan } from "./scan.js";
import { buildWatchServer } from "./server.js";
import { StateStore } from "./state.js";
import { readSubscriptions } from "./subscriptions.js";

async function main(): Promise<void> {
  const cfg = loadWatchConfig();
  const engine = new HttpEngineWatchClient(cfg.engineUrl);
  const state = new StateStore(cfg.stateDir);
  const subscriptions = () => readSubscriptions(cfg.subscriptionsFile);

  const scan = () =>
    runScan({ engine, subscriptions, state, sendAlert: sendWebhookAlert }).then((r) => {
      // eslint-disable-next-line no-console
      console.error(`[watch] scan: ${r.subscriptions} sub, ${r.alerts} alert`);
    }).catch((err) => {
      // eslint-disable-next-line no-console
      console.error("[watch] scan gagal:", (err as Error).message);
    });

  if (!cron.validate(cfg.cronSchedule)) {
    throw new Error(`CRON_SCHEDULE tak valid: ${cfg.cronSchedule}`);
  }
  cron.schedule(cfg.cronSchedule, scan);

  const app = buildWatchServer({ engine, subscriptions, state });
  await app.listen({ host: "0.0.0.0", port: cfg.port });
  // eslint-disable-next-line no-console
  console.error(`[watch] siap :${cfg.port} · engine=${cfg.engineUrl} · cron=${cfg.cronSchedule} · subs=${cfg.subscriptionsFile}`);

  await scan(); // scan awal saat start
}

main().catch((err) => {
  // eslint-disable-next-line no-console
  console.error("[watch] gagal start:", err);
  process.exit(1);
});
