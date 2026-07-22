import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

import dotenv from "dotenv";

const __dirname = fileURLToPath(new URL(".", import.meta.url));
dotenv.config({ path: resolve(__dirname, "../../../.env") });

export interface WatchConfig {
  engineUrl: string;
  subscriptionsFile: string; // gateway store (dibaca read-only)
  stateDir: string; // state milik worker sendiri
  cronSchedule: string;
  port: number;
}

export function loadWatchConfig(): WatchConfig {
  const gatewayData =
    process.env.GATEWAY_DATA_DIR ?? resolve(__dirname, "../../../apps/server/data");
  return {
    engineUrl: process.env.ENGINE_URL ?? "http://localhost:8100",
    subscriptionsFile:
      process.env.WATCH_SUBSCRIPTIONS_FILE ?? resolve(gatewayData, "gateway.json"),
    stateDir: process.env.WATCH_DATA_DIR ?? resolve(__dirname, "../data"),
    cronSchedule: process.env.CRON_SCHEDULE ?? "0 */6 * * *",
    port: Number(process.env.WATCH_PORT ?? 8795),
  };
}
