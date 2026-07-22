import { mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { describe, expect, it } from "vitest";

import type { EngineWatchClient, NeardupsQuery, NeardupsResult } from "../src/engine.js";
import { runScan, type AlertPayload } from "../src/scan.js";
import { StateStore } from "../src/state.js";
import type { Subscription } from "../src/types.js";

function sub(over: Partial<Subscription> = {}): Subscription {
  return {
    id: "sub_1",
    cert_id: "1",
    webhook_url: "https://hook.test/x",
    created_at: 0,
    entry_id: 5,
    last_checked: 10,
    ...over,
  };
}

/** Engine palsu: mengembalikan match yang diskrip per pemanggilan. */
class ScriptedEngine implements EngineWatchClient {
  public calls: NeardupsQuery[] = [];
  constructor(private script: NeardupsResult[]) {}
  async neardups(q: NeardupsQuery): Promise<NeardupsResult> {
    this.calls.push(q);
    return this.script.shift() ?? { matches: [], corpus_size: 10 };
  }
}

function freshState() {
  return new StateStore(mkdtempSync(join(tmpdir(), "watch-")));
}

describe("runScan", () => {
  it("match salinan baru → alert + draft challenge + majukan titik periksa", async () => {
    const engine = new ScriptedEngine([
      { matches: [{ entry_id: 42, matched: 3, min_hamming: 6, source: "preseed", uri: "u" }], corpus_size: 42 },
    ]);
    const state = freshState();
    const sent: AlertPayload[] = [];

    const report = await runScan({
      engine,
      subscriptions: () => [sub()],
      state,
      sendAlert: async (p) => void sent.push(p),
      now: () => 1000,
    });

    expect(report.alerts).toBe(1);
    expect(sent[0].match.entry_id).toBe(42);
    expect(sent[0].draft.watched_cert_id).toBe("1");
    expect(sent[0].draft.copy_entry_id).toBe(42);
    expect(state.listAlerts()).toHaveLength(1);
    // Query sejak last_checked (10), pakai entry_id
    expect(engine.calls[0]).toMatchObject({ entry_id: 5, since_entry_id: 10 });
    // Titik periksa maju ke corpus_size
    expect(state.lastChecked("sub_1")).toBe(42);
  });

  it("tak ada match → tak ada alert, titik periksa tetap maju", async () => {
    const engine = new ScriptedEngine([{ matches: [], corpus_size: 20 }]);
    const state = freshState();
    const report = await runScan({
      engine,
      subscriptions: () => [sub()],
      state,
      sendAlert: async () => {},
    });
    expect(report.alerts).toBe(0);
    expect(state.lastChecked("sub_1")).toBe(20);
  });

  it("tak dobel-alert: siklus kedua mulai dari titik yang sudah maju", async () => {
    const engine = new ScriptedEngine([
      { matches: [{ entry_id: 42, matched: 2, min_hamming: 10 }], corpus_size: 42 },
      { matches: [], corpus_size: 42 },
    ]);
    const state = freshState();
    const deps = {
      engine,
      subscriptions: () => [sub()],
      state,
      sendAlert: async () => {},
    };
    await runScan(deps);
    await runScan(deps);
    // Siklus kedua bertanya sejak 42 (bukan 10 lagi)
    expect(engine.calls[1]).toMatchObject({ since_entry_id: 42 });
    expect(state.listAlerts()).toHaveLength(1); // hanya sekali
  });

  it("subscription pakai phashes bila tak ada entry_id", async () => {
    const engine = new ScriptedEngine([{ matches: [], corpus_size: 3 }]);
    const state = freshState();
    await runScan({
      engine,
      subscriptions: () => [sub({ entry_id: undefined, phashes: ["0xa", "0xb", "0xc", "0xd"] })],
      state,
      sendAlert: async () => {},
    });
    expect(engine.calls[0]).toMatchObject({ phashes: ["0xa", "0xb", "0xc", "0xd"], since_entry_id: 10 });
  });
});
