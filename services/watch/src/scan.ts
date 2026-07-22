/**
 * Inti Watch: satu siklus re-scan. Untuk tiap subscription, tanya engine adakah
 * entri NEAR_DUP yang MASUK registry setelah titik yang sudah diperiksa. Match →
 * alert (webhook) + draft challenge → catat → majukan titik periksa (tak dobel-alert).
 *
 * deps disuntik → dites tanpa engine/jaringan sungguhan.
 */

import type { EngineWatchClient } from "./engine.js";
import type { StateStore } from "./state.js";
import type { DraftChallenge, NeardupMatch, Subscription } from "./types.js";

export interface AlertPayload {
  subscription: Subscription;
  match: NeardupMatch;
  draft: DraftChallenge;
}

export interface ScanDeps {
  engine: EngineWatchClient;
  subscriptions: () => Subscription[];
  state: StateStore;
  sendAlert: (payload: AlertPayload) => Promise<void>;
  now?: () => number;
}

export interface ScanReport {
  subscriptions: number;
  alerts: number;
}

export function buildDraftChallenge(
  sub: Subscription,
  m: NeardupMatch,
  detectedAt: number,
): DraftChallenge {
  return {
    watched_cert_id: sub.cert_id,
    watched_entry_id: sub.entry_id ?? null,
    copy_entry_id: m.entry_id,
    copy_source: m.source ?? null,
    copy_uri: m.uri ?? null,
    matched_hashes: m.matched,
    min_hamming: m.min_hamming,
    evidence_note:
      "Salinan terdeteksi masuk registry SETELAH aset diawasi. Bila salinan ini " +
      "memperoleh sertifikat, ajukan challenge dengan bukti prioritas: entri diawasi " +
      "+ timestamp commit/mint (bukti admissible §5.6).",
    detected_at: detectedAt,
  };
}

export async function runScan(deps: ScanDeps): Promise<ScanReport> {
  const now = deps.now ?? (() => Math.floor(Date.now() / 1000));
  const subs = deps.subscriptions();
  let alerts = 0;

  for (const sub of subs) {
    const since = deps.state.lastChecked(sub.id) ?? sub.last_checked;

    const query =
      sub.entry_id != null
        ? { entry_id: sub.entry_id, since_entry_id: since }
        : sub.phashes
          ? { phashes: sub.phashes, since_entry_id: since }
          : null;
    if (!query) continue; // subscription tanpa fingerprint — tak bisa diawasi

    const { matches, corpus_size } = await deps.engine.neardups(query);

    for (const m of matches) {
      const draft = buildDraftChallenge(sub, m, now());
      await deps.sendAlert({ subscription: sub, match: m, draft });
      deps.state.recordAlert(draft);
      alerts++;
    }

    // Majukan titik periksa → entri yang sama tak memicu alert lagi siklus depan.
    deps.state.setLastChecked(sub.id, corpus_size);
  }

  deps.state.persist();
  return { subscriptions: subs.length, alerts };
}
