/** State milik worker: last_checked per subscription + log alert (dashboard-lite).
 *  Tulis-atomik. TIDAK menyentuh file gateway. */

import { mkdirSync, readFileSync, renameSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";

import type { DraftChallenge } from "./types.js";

interface StateData {
  lastChecked: Record<string, number>;
  alerts: DraftChallenge[];
}

export class StateStore {
  private path: string;
  private data: StateData;

  constructor(dir: string) {
    this.path = join(dir, "watch.json");
    this.data = this.load();
  }

  private load(): StateData {
    try {
      const d = JSON.parse(readFileSync(this.path, "utf8")) as Partial<StateData>;
      return { lastChecked: d.lastChecked ?? {}, alerts: d.alerts ?? [] };
    } catch {
      return { lastChecked: {}, alerts: [] };
    }
  }

  lastChecked(subId: string): number | undefined {
    return this.data.lastChecked[subId];
  }

  setLastChecked(subId: string, n: number): void {
    this.data.lastChecked[subId] = n;
  }

  recordAlert(draft: DraftChallenge): void {
    this.data.alerts.push(draft);
  }

  listAlerts(): DraftChallenge[] {
    return this.data.alerts;
  }

  persist(): void {
    mkdirSync(dirname(this.path), { recursive: true });
    const tmp = this.path + ".tmp";
    writeFileSync(tmp, JSON.stringify(this.data, null, 2));
    renameSync(tmp, this.path);
  }
}
