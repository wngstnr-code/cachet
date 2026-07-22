/** Jalankan SATU siklus re-scan lalu keluar (CLI: `pnpm rescan`). */

import { sendWebhookAlert } from "./alerts.js";
import { loadWatchConfig } from "./config.js";
import { HttpEngineWatchClient } from "./engine.js";
import { runScan } from "./scan.js";
import { StateStore } from "./state.js";
import { readSubscriptions } from "./subscriptions.js";

async function main(): Promise<void> {
  const cfg = loadWatchConfig();
  const report = await runScan({
    engine: new HttpEngineWatchClient(cfg.engineUrl),
    subscriptions: () => readSubscriptions(cfg.subscriptionsFile),
    state: new StateStore(cfg.stateDir),
    sendAlert: sendWebhookAlert,
  });
  // eslint-disable-next-line no-console
  console.log(`[watch] rescan: ${report.subscriptions} sub, ${report.alerts} alert`);
}

main().catch((err) => {
  // eslint-disable-next-line no-console
  console.error("[watch] rescan gagal:", err);
  process.exit(1);
});
